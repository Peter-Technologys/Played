// lib/core/services/auth_service.dart
//
// Calls https://petersmartlink.com/auth/* endpoints.
//
// SECURITY: access_token and refresh_token are stored ONLY in
// flutter_secure_storage (Android Keystore / iOS Secure Enclave).
// Non-sensitive profile fields (userId, email, name, avatar) remain in
// SharedPreferences for fast synchronous access.
//
// Auto-refreshes token when expired (checks exp from JWT payload).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

// Derived from Environment.workerUrl so the backend domain is never
// hardcoded here. Environment.workerUrl is injected at build time via
// --dart-define=WORKER_URL=https://... (see lib/core/config/environment.dart).
String get _kAuthBase => '${Environment.workerUrl}/auth';

// Secure storage keys (tokens — never in SharedPreferences)
const _kSecureAccessToken  = 'otya_access_token';
const _kSecureRefreshToken = 'otya_refresh_token';

// SharedPreferences keys (non-sensitive profile data only)
const _kUserId         = 'otya_user_id';
const _kUserEmail      = 'otya_user_email';
const _kUserName       = 'otya_user_name';
const _kUserAvatar     = 'otya_user_avatar';
const _kIsVerified     = 'otya_is_verified';

// flutter_secure_storage instance — shared across all reads/writes in this file.
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// ── Result types ──────────────────────────────────────────────────────────────

class AuthResult {
  final bool ok;
  final String? error;
  final String? accessToken;
  final String? refreshToken;
  final UserProfile? user;

  const AuthResult({
    required this.ok,
    this.error,
    this.accessToken,
    this.refreshToken,
    this.user,
  });
}

class UserProfile {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final bool isVerified;

  const UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.isVerified,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id:         json['id'] as String,
        email:      json['email'] as String,
        name:       json['name'] as String?,
        avatarUrl:  json['avatar_url'] as String?,
        isVerified: (json['is_verified'] as int? ?? 0) == 1,
      );
}

// ── JWT helpers ───────────────────────────────────────────────────────────────

Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1];
    // Pad base64url to a multiple of 4
    while (payload.length % 4 != 0) payload += '=';
    final decoded = base64Url.decode(payload.replaceAll('-', '+').replaceAll('_', '/'));
    return jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

bool _isTokenExpired(String token) {
  final payload = _decodeJwtPayload(token);
  if (payload == null) return true;
  final exp = payload['exp'] as int?;
  if (exp == null) return true;
  // Treat as expired 60 seconds early to avoid edge cases
  return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 60;
}

// ── AuthService ───────────────────────────────────────────────────────────────

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static final http.Client _client = http.Client();
  static const Duration _timeout   = Duration(seconds: 15);

  // ── Cached state (loaded from prefs on first access) ─────────────────────

  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _userAvatar;
  bool    _isVerified = false;
  bool    _loaded     = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    // Tokens from secure storage
    _accessToken  = await _secureStorage.read(key: _kSecureAccessToken);
    _refreshToken = await _secureStorage.read(key: _kSecureRefreshToken);
    // Profile from SharedPreferences (non-sensitive)
    final prefs = await SharedPreferences.getInstance();
    _userId     = prefs.getString(_kUserId);
    _userEmail  = prefs.getString(_kUserEmail);
    _userName   = prefs.getString(_kUserName);
    _userAvatar = prefs.getString(_kUserAvatar);
    _isVerified = prefs.getBool(_kIsVerified) ?? false;
    _loaded     = true;
  }

  Future<void> _persist({
    String? accessToken,
    String? refreshToken,
    UserProfile? user,
  }) async {
    // Tokens → secure storage only
    if (accessToken != null) {
      _accessToken = accessToken;
      await _secureStorage.write(key: _kSecureAccessToken, value: accessToken);
    }
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _secureStorage.write(key: _kSecureRefreshToken, value: refreshToken);
    }
    // Profile → SharedPreferences (non-sensitive)
    if (user != null) {
      _userId     = user.id;
      _userEmail  = user.email;
      _userName   = user.name;
      _userAvatar = user.avatarUrl;
      _isVerified = user.isVerified;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserId,    user.id);
      await prefs.setString(_kUserEmail, user.email);
      if (user.name != null)      await prefs.setString(_kUserName,   user.name!);
      if (user.avatarUrl != null) await prefs.setString(_kUserAvatar, user.avatarUrl!);
      await prefs.setBool(_kIsVerified, user.isVerified);
    }
  }

  Future<void> _clearPersisted() async {
    // Remove tokens from secure storage
    await _secureStorage.delete(key: _kSecureAccessToken);
    await _secureStorage.delete(key: _kSecureRefreshToken);
    _accessToken  = null;
    _refreshToken = null;
    // Remove profile from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _userId     = null;
    _userEmail  = null;
    _userName   = null;
    _userAvatar = null;
    _isVerified = false;
    for (final k in [_kUserId, _kUserEmail, _kUserName, _kUserAvatar]) {
      await prefs.remove(k);
    }
    await prefs.remove(_kIsVerified);
  }

  // ── Public getters ────────────────────────────────────────────────────────

  /// Synchronous login check. May return false on cold start if
  /// [_ensureLoaded] has not yet completed — use [checkIsLoggedIn] instead
  /// when you cannot guarantee that loading has already happened.
  bool get isLoggedIn => _accessToken != null && _userId != null;

  /// Async login check that awaits [_ensureLoaded] before reading state.
  /// Prefer this over [isLoggedIn] on first access after a cold start.
  Future<bool> checkIsLoggedIn() async {
    await _ensureLoaded();
    return _accessToken != null && _userId != null;
  }

  String? get userId    => _userId;
  String? get userEmail => _userEmail;
  String? get userName  => _userName;
  bool    get isVerified => _isVerified;

  // ── Token management ──────────────────────────────────────────────────────

  /// Returns a valid access token, refreshing if expired.
  /// Tokens are read from and written to flutter_secure_storage exclusively.
  Future<String?> getValidToken() async {
    await _ensureLoaded();
    if (_accessToken == null) return null;
    if (!_isTokenExpired(_accessToken!)) return _accessToken;
    // Try to refresh
    if (_refreshToken == null) return null;
    try {
      final res = await _client.post(
        Uri.parse('$_kAuthBase/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newToken = data['access_token'] as String?;
        if (newToken != null) {
          // Write directly to secure storage (not SharedPreferences)
          _accessToken = newToken;
          await _secureStorage.write(key: _kSecureAccessToken, value: newToken);
          return newToken;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Token refresh failed: $e');
    }
    return null;
  }

  // ── Auth methods ──────────────────────────────────────────────────────────

  Future<AuthResult> register(String email, String password, String? name) async {
    try {
      final res = await _client.post(
        Uri.parse('$_kAuthBase/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, if (name != null) 'name': name}),
      ).timeout(_timeout);
      return _handleAuthResponse(res);
    } catch (e) {
      return AuthResult(ok: false, error: 'Network error: $e');
    }
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      final res = await _client.post(
        Uri.parse('$_kAuthBase/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(_timeout);
      return _handleAuthResponse(res);
    } catch (e) {
      return AuthResult(ok: false, error: 'Network error: $e');
    }
  }

  Future<AuthResult> loginWithGoogle(String idToken, String driveAccessToken) async {
    try {
      final res = await _client.post(
        Uri.parse('$_kAuthBase/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken, 'drive_access_token': driveAccessToken}),
      ).timeout(_timeout);
      return _handleAuthResponse(res);
    } catch (e) {
      return AuthResult(ok: false, error: 'Network error: $e');
    }
  }

  Future<void> logout() async {
    await _ensureLoaded();
    if (_refreshToken != null) {
      try {
        await _client.post(
          Uri.parse('$_kAuthBase/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': _refreshToken}),
        ).timeout(_timeout);
      } catch (e) {
        debugPrint('[AuthService] Logout request failed: $e');
      }
    }
    await _clearPersisted();
  }

  Future<UserProfile?> getProfile() async {
    final token = await getValidToken();
    if (token == null) return null;
    try {
      final res = await _client.get(
        Uri.parse('$_kAuthBase/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      await _persist(user: user);
      return user;
    } catch (e) {
      debugPrint('[AuthService] getProfile failed: $e');
      return null;
    }
  }

  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    final token = await getValidToken();
    if (token == null) return;
    try {
      final body = <String, dynamic>{};
      if (name != null)      body['name']       = name;
      if (avatarUrl != null) body['avatar_url']  = avatarUrl;
      final res = await _client.patch(
        Uri.parse('$_kAuthBase/me'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
        await _persist(user: user);
      }
    } catch (e) {
      debugPrint('[AuthService] updateProfile failed: $e');
    }
  }

  Future<void> sendVerificationOtp() async {
    final token = await getValidToken();
    if (token == null) return;
    try {
      await _client.post(
        Uri.parse('$_kAuthBase/send-verification'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[AuthService] sendVerificationOtp failed: $e');
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final token = await getValidToken();
    if (token == null) return false;
    try {
      final res = await _client.post(
        Uri.parse('$_kAuthBase/verify-email'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'otp': otp}),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        _isVerified = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kIsVerified, true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] verifyOtp failed: $e');
      return false;
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _client.post(
        Uri.parse('$_kAuthBase/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[AuthService] forgotPassword failed: $e');
    }
  }

  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    try {
      final res = await _client.post(
        Uri.parse('$_kAuthBase/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp, 'new_password': newPassword}),
      ).timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AuthService] resetPassword failed: $e');
      return false;
    }
  }

  Future<void> deleteAccount() async {
    final token = await getValidToken();
    if (token == null) return;
    try {
      await _client.post(
        Uri.parse('$_kAuthBase/delete-account'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[AuthService] deleteAccount failed: $e');
    }
    await _clearPersisted();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<AuthResult> _handleAuthResponse(http.Response res) async {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && data['ok'] == true) {
        final accessToken  = data['access_token']  as String?;
        final refreshToken = data['refresh_token'] as String?;
        final userJson     = data['user']           as Map<String, dynamic>?;
        final user         = userJson != null ? UserProfile.fromJson(userJson) : null;
        await _persist(accessToken: accessToken, refreshToken: refreshToken, user: user);
        return AuthResult(ok: true, accessToken: accessToken, refreshToken: refreshToken, user: user);
      }
      return AuthResult(ok: false, error: data['error'] as String? ?? 'Unknown error');
    } catch (e) {
      return AuthResult(ok: false, error: 'Failed to parse response: $e');
    }
  }
}
