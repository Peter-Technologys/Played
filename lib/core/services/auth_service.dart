// lib/core/services/auth_service.dart
//
// Calls https://petersmartlink.com/auth/* endpoints.
//
// SECURITY: access_token and refresh_token are stored ONLY in
// flutter_secure_storage (Android Keystore / iOS Secure Enclave).
// Non-sensitive profile fields (private userId, public Otya ID, email, name,
// avatar) remain in SharedPreferences for fast synchronous access.
//
// Auto-refreshes token when expired (checks exp from JWT payload).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import 'http_client.dart';

String get _kAuthBase => '${Environment.workerUrl}/auth';

const _kSecureAccessToken = 'otya_access_token';
const _kSecureRefreshToken = 'otya_refresh_token';
const _kUserId = 'otya_user_id';
const _kPublicId = 'otya_public_id';
const _kUserEmail = 'otya_user_email';
const _kUserName = 'otya_user_name';
const _kUserAvatar = 'otya_user_avatar';
const _kIsVerified = 'otya_is_verified';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class AuthResult {
  final bool ok;
  final String? error;
  final String? errorCode;
  final String? accessToken;
  final String? refreshToken;
  final UserProfile? user;

  const AuthResult({
    required this.ok,
    this.error,
    this.errorCode,
    this.accessToken,
    this.refreshToken,
    this.user,
  });

  bool get twoFactorRequired => errorCode == 'TWO_FACTOR_REQUIRED';
  bool get twoFactorInvalid => errorCode == 'TWO_FACTOR_INVALID';
}

class UserProfile {
  final String id;
  final String? otyaId;
  final String? email;
  final String? name;
  final String? avatarUrl;
  final bool isVerified;

  const UserProfile({
    required this.id,
    this.otyaId,
    this.email,
    this.name,
    this.avatarUrl,
    required this.isVerified,
  });

  bool get hasEmail => email?.trim().isNotEmpty == true;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final verified = json['is_verified'];
    final rawEmail = json['email'];
    final email = rawEmail is String && rawEmail.trim().isNotEmpty
        ? rawEmail.trim()
        : null;
    final rawPublicId = json['otya_id'];
    final publicId = rawPublicId is String && rawPublicId.trim().isNotEmpty
        ? rawPublicId.trim().toUpperCase()
        : null;
    return UserProfile(
      id: json['id'] as String,
      otyaId: publicId,
      email: email,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: verified == true || verified == 1,
    );
  }
}

Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1];
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    final decoded = base64Url.decode(
      payload.replaceAll('-', '+').replaceAll('_', '/'),
    );
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
  return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 60;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const termsVersion = '2026-08-28';
  static const privacyVersion = '2026-08-28';

  http.Client get _client => AppHttpClient.instance.client;
  static const Duration _timeout = Duration(seconds: 15);

  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _otyaPublicId;
  String? _userEmail;
  String? _userName;
  String? _userAvatar;
  bool _isVerified = false;
  bool _loaded = false;
  Future<String?>? _refreshInFlight;
  int _sessionGeneration = 0;

  static const _networkError =
      'Could not reach Otya right now. Check your connection and try again.';

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _accessToken = await _secureStorage.read(key: _kSecureAccessToken);
    _refreshToken = await _secureStorage.read(key: _kSecureRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_kUserId);
    _otyaPublicId = prefs.getString(_kPublicId);
    _userEmail = prefs.getString(_kUserEmail);
    _userName = prefs.getString(_kUserName);
    _userAvatar = prefs.getString(_kUserAvatar);
    _isVerified = prefs.getBool(_kIsVerified) ?? false;
    _loaded = true;
  }

  Future<void> _persist({
    String? accessToken,
    String? refreshToken,
    UserProfile? user,
  }) async {
    if (accessToken != null) {
      _accessToken = accessToken;
      await _secureStorage.write(key: _kSecureAccessToken, value: accessToken);
    }
    if (refreshToken != null) {
      if (_refreshToken != refreshToken) _sessionGeneration++;
      _refreshToken = refreshToken;
      await _secureStorage.write(key: _kSecureRefreshToken, value: refreshToken);
    }
    if (user != null) {
      _userId = user.id;
      _otyaPublicId = user.otyaId;
      _userEmail = user.email;
      _userName = user.name;
      _userAvatar = user.avatarUrl;
      _isVerified = user.isVerified;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserId, user.id);
      if (user.otyaId != null && user.otyaId!.trim().isNotEmpty) {
        await prefs.setString(_kPublicId, user.otyaId!);
      } else {
        await prefs.remove(_kPublicId);
      }
      if (user.email != null && user.email!.trim().isNotEmpty) {
        await prefs.setString(_kUserEmail, user.email!);
      } else {
        await prefs.remove(_kUserEmail);
      }
      if (user.name != null && user.name!.trim().isNotEmpty) {
        await prefs.setString(_kUserName, user.name!);
      } else {
        await prefs.remove(_kUserName);
      }
      if (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty) {
        await prefs.setString(_kUserAvatar, user.avatarUrl!);
      } else {
        await prefs.remove(_kUserAvatar);
      }
      await prefs.setBool(_kIsVerified, user.isVerified);
    }
  }

  Future<void> _clearPersisted() async {
    _sessionGeneration++;
    await _secureStorage.delete(key: _kSecureAccessToken);
    await _secureStorage.delete(key: _kSecureRefreshToken);
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    _userId = null;
    _otyaPublicId = null;
    _userEmail = null;
    _userName = null;
    _userAvatar = null;
    _isVerified = false;
    for (final key in [
      _kUserId,
      _kPublicId,
      _kUserEmail,
      _kUserName,
      _kUserAvatar,
    ]) {
      await prefs.remove(key);
    }
    await prefs.remove(_kIsVerified);
  }

  bool get isLoggedIn => _loaded && _accessToken != null && _userId != null;

  Future<bool> checkIsLoggedIn() async {
    await _ensureLoaded();
    return _accessToken != null && _userId != null;
  }

  String? get userId => _userId;
  String? get otyaPublicId => _otyaPublicId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userAvatar => _userAvatar;
  bool get isVerified => _isVerified;

  Future<String?> getValidToken() async {
    await _ensureLoaded();
    final accessToken = _accessToken;
    if (accessToken == null) return null;
    if (!_isTokenExpired(accessToken)) return accessToken;

    final existingRefresh = _refreshInFlight;
    if (existingRefresh != null) return existingRefresh;

    final refresh = _refreshAccessToken();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearPersisted();
      return null;
    }

    final generation = _sessionGeneration;
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_timeout);

      if (generation != _sessionGeneration || _refreshToken != refreshToken) {
        return null;
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final newToken = decoded['access_token'] as String?;
          if (newToken != null && newToken.isNotEmpty) {
            _accessToken = newToken;
            await _secureStorage.write(key: _kSecureAccessToken, value: newToken);
            return newToken;
          }
        }
      }

      if (res.statusCode == 401 || res.statusCode == 403) {
        await _clearPersisted();
      }
    } catch (e) {
      debugPrint('[AuthService] Token refresh failed: ${e.runtimeType}');
    }
    return null;
  }

  Future<AuthResult> register(
    String email,
    String password,
    String? name, {
    required bool termsAccepted,
    required bool privacyAccepted,
    bool marketingConsent = false,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              if (name != null) 'name': name,
              'terms_accepted': termsAccepted,
              'terms_version': termsVersion,
              'privacy_accepted': privacyAccepted,
              'privacy_version': privacyVersion,
              'marketing_consent': marketingConsent,
            }),
          )
          .timeout(_timeout);
      return _handleAuthResponse(res);
    } catch (e) {
      debugPrint('[AuthService] Register request failed: ${e.runtimeType}');
      return const AuthResult(ok: false, error: _networkError);
    }
  }

  Future<AuthResult> login(
    String email,
    String password, {
    String? totpCode,
    String? recoveryCode,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              if (totpCode != null && totpCode.trim().isNotEmpty)
                'totp_code': totpCode.trim(),
              if (recoveryCode != null && recoveryCode.trim().isNotEmpty)
                'recovery_code': recoveryCode.trim(),
            }),
          )
          .timeout(_timeout);
      return _handleAuthResponse(res);
    } catch (e) {
      debugPrint('[AuthService] Login request failed: ${e.runtimeType}');
      return const AuthResult(ok: false, error: _networkError);
    }
  }

  Future<AuthResult> loginWithGoogle(
    String idToken, {
    bool termsAccepted = false,
    bool privacyAccepted = false,
    bool marketingConsent = false,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': idToken,
              'terms_accepted': termsAccepted,
              'terms_version': termsVersion,
              'privacy_accepted': privacyAccepted,
              'privacy_version': privacyVersion,
              'marketing_consent': marketingConsent,
            }),
          )
          .timeout(_timeout);
      return _handleAuthResponse(res);
    } catch (e) {
      debugPrint('[AuthService] Google auth request failed: ${e.runtimeType}');
      return const AuthResult(ok: false, error: _networkError);
    }
  }

  Future<void> logout() async {
    await _ensureLoaded();
    final refreshToken = _refreshToken;
    if (refreshToken != null) {
      try {
        await _client
            .post(
              Uri.parse('$_kAuthBase/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(_timeout);
      } catch (e) {
        debugPrint('[AuthService] Logout request failed: ${e.runtimeType}');
      }
    }
    await _clearPersisted();
  }

  Future<UserProfile?> getProfile() async {
    final token = await getValidToken();
    if (token == null) return null;
    try {
      final res = await _client
          .get(
            Uri.parse('$_kAuthBase/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['user'] is! Map<String, dynamic>) {
        return null;
      }
      final user = UserProfile.fromJson(
        decoded['user'] as Map<String, dynamic>,
      );
      await _persist(user: user);
      return user;
    } catch (e) {
      debugPrint('[AuthService] getProfile failed: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    final token = await getValidToken();
    if (token == null) return;
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;
      final res = await _client
          .patch(
            Uri.parse('$_kAuthBase/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> &&
            decoded['user'] is Map<String, dynamic>) {
          final user = UserProfile.fromJson(
            decoded['user'] as Map<String, dynamic>,
          );
          await _persist(user: user);
        }
      }
    } catch (e) {
      debugPrint('[AuthService] updateProfile failed: ${e.runtimeType}');
    }
  }

  Future<bool> sendVerificationOtp() async {
    final token = await getValidToken();
    if (token == null) return false;
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/send-verification'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[AuthService] sendVerificationOtp failed: ${e.runtimeType}');
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final token = await getValidToken();
    if (token == null) return false;
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/verify-email'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'otp': otp}),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _isVerified = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kIsVerified, true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] verifyOtp failed: ${e.runtimeType}');
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[AuthService] forgotPassword failed: ${e.runtimeType}');
      return false;
    }
  }

  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_kAuthBase/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'new_password': newPassword,
            }),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AuthService] resetPassword failed: ${e.runtimeType}');
      return false;
    }
  }

  /// Permanently deletes the authenticated Otya cloud account.
  Future<void> deleteAccount() async {
    final token = await getValidToken();
    if (token == null) {
      throw StateError('No valid Otya session is available.');
    }

    final res = await _client
        .post(
          Uri.parse('$_kAuthBase/delete-account'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(
        'Otya account deletion was not confirmed (HTTP ${res.statusCode}).',
      );
    }

    await _clearPersisted();
  }

  Future<AuthResult> _handleAuthResponse(http.Response res) async {
    final raw = res.body.trim();
    if (raw.isEmpty) {
      return AuthResult(
        ok: false,
        error:
            'Authentication service returned an empty response (HTTP ${res.statusCode}). Please try again.',
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AuthResult(
          ok: false,
          error:
              'Authentication service returned an invalid response (HTTP ${res.statusCode}).',
        );
      }
      final data = decoded;
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          data['ok'] == true) {
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final userJson = data['user'] as Map<String, dynamic>?;
        final user = userJson != null ? UserProfile.fromJson(userJson) : null;
        await _persist(
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
        );
        return AuthResult(
          ok: true,
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
        );
      }
      final error = data['error'];
      final code = data['code'];
      return AuthResult(
        ok: false,
        error: error is String && error.trim().isNotEmpty
            ? error
            : 'Authentication failed. Please try again.',
        errorCode: code is String ? code : null,
      );
    } catch (e) {
      debugPrint(
        '[AuthService] Invalid auth response: HTTP ${res.statusCode}, ${e.runtimeType}',
      );
      return AuthResult(
        ok: false,
        error:
            'Authentication service response was invalid (HTTP ${res.statusCode}).',
      );
    }
  }
}
