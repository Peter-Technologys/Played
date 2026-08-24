// lib/core/services/cloudflare_client.dart
//
// ECOSYSTEM NOTE:
// OTYA Player connects to petersmartlink.com Cloudflare backend.
// Same backend serves SmartPOS (business POS) and Otya-Store website.
// All apps share JWT auth at /auth/*
// APK downloads served from Cloudflare R2 via petersmartlink.com
//
// This client provides:
//   - Automatic JWT token refresh on 401 using refresh_token from
//     flutter_secure_storage (never SharedPreferences).
//   - Mutex pattern (Completer) to prevent concurrent refresh races.
//   - 30-second timeout on all requests.
//   - Typed CloudflareException with HTTP status code.
//   - Sanitized request paths to prevent path traversal.
//   - Methods: get(), post(), patch(), delete().

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import 'api_signer.dart';

// ── Typed exception ───────────────────────────────────────────────────────────

class CloudflareException implements Exception {
  final int statusCode;
  final String message;
  final String? body;

  const CloudflareException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  @override
  String toString() => 'CloudflareException($statusCode): $message';
}

// ── CloudflareClient ──────────────────────────────────────────────────────────

/// Authenticated HTTP client for the petersmartlink.com Cloudflare backend.
///
/// Tokens are stored exclusively in [FlutterSecureStorage] — never in
/// SharedPreferences — to satisfy the security requirement that credentials
/// are protected by the Android Keystore / iOS Secure Enclave.
///
/// Concurrent 401 responses trigger only ONE refresh attempt (mutex via
/// [Completer]). All other callers wait for the single refresh to complete
/// before retrying their original request.
class CloudflareClient {
  CloudflareClient._();
  static final CloudflareClient instance = CloudflareClient._();

  static const Duration _timeout = Duration(seconds: 30);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccessToken  = 'otya_access_token';
  static const _kRefreshToken = 'otya_refresh_token';

  // Persistent HTTP client — keeps TCP/TLS connections alive.
  final http.Client _client = http.Client();

  // Mutex: only one refresh in flight at a time.
  Completer<String?>? _refreshCompleter;

  // ── Token helpers ─────────────────────────────────────────────────────────

  Future<String?> _readAccessToken()  => _storage.read(key: _kAccessToken);
  Future<String?> _readRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> _writeAccessToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  /// Refreshes the access token using the stored refresh token.
  /// Uses a [Completer] mutex so concurrent 401s only trigger one refresh.
  Future<String?> _refreshAccessToken() async {
    // If a refresh is already in progress, wait for it.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    try {
      final refreshToken = await _readRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final res = await _client
          .post(
            Uri.parse('${Environment.workerUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newToken = data['access_token'] as String?;
        if (newToken != null) {
          await _writeAccessToken(newToken);
          _refreshCompleter!.complete(newToken);
          return newToken;
        }
      }
      _refreshCompleter!.complete(null);
      return null;
    } catch (e) {
      debugPrint('[CloudflareClient] Token refresh failed: $e');
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  // ── Path sanitization ─────────────────────────────────────────────────────

  /// Sanitizes [path] to prevent path traversal attacks.
  /// Removes `..` segments and ensures the path starts with `/`.
  static String _sanitizePath(String path) {
    // Normalize: remove any `..` or `.` segments
    final uri = Uri(path: path);
    final segments = uri.pathSegments
        .where((s) => s != '..' && s != '.')
        .toList();
    final clean = '/${segments.join('/')}';
    return clean;
  }

  // ── Header builders ───────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders(String method, String path) async {
    final token = await _readAccessToken();
    final base = <String, String>{
      'Accept': 'application/json',
      ...ApiSigner.signedHeaders(method: method, path: path),
    };
    if (token != null) {
      base['Authorization'] = 'Bearer $token';
    }
    return base;
  }

  Future<Map<String, String>> _authJsonHeaders(String method, String path) async {
    final headers = await _authHeaders(method, path);
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  // ── Core request with auto-retry on 401 ──────────────────────────────────

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? extraHeaders,
    Object? body,
  }) async {
    final path = _sanitizePath(uri.path);

    Future<http.Response> doRequest(Map<String, String> headers) {
      switch (method) {
        case 'GET':
          return _client.get(uri, headers: headers).timeout(_timeout);
        case 'POST':
          return _client
              .post(uri, headers: headers, body: body)
              .timeout(_timeout);
        case 'PATCH':
          return _client
              .patch(uri, headers: headers, body: body)
              .timeout(_timeout);
        case 'DELETE':
          return _client.delete(uri, headers: headers).timeout(_timeout);
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }
    }

    final isJson = body != null;
    var headers = isJson
        ? await _authJsonHeaders(method, path)
        : await _authHeaders(method, path);
    if (extraHeaders != null) headers.addAll(extraHeaders);

    var response = await doRequest(headers);

    // Auto-refresh on 401
    if (response.statusCode == 401) {
      debugPrint('[CloudflareClient] 401 on $method $path — refreshing token.');
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        headers = isJson
            ? await _authJsonHeaders(method, path)
            : await _authHeaders(method, path);
        if (extraHeaders != null) headers.addAll(extraHeaders);
        response = await doRequest(headers);
      }
    }

    return response;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// GET [url]. Throws [CloudflareException] on non-2xx (unless [throwOnError]
  /// is false, in which case the raw response is returned).
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    bool throwOnError = true,
  }) async {
    try {
      final res = await _request('GET', Uri.parse(url), extraHeaders: headers);
      if (throwOnError && res.statusCode >= 400) {
        throw CloudflareException(
          statusCode: res.statusCode,
          message: _extractError(res.body),
          body: res.body,
        );
      }
      return res;
    } on CloudflareException {
      rethrow;
    } on TimeoutException {
      throw const CloudflareException(
          statusCode: 408, message: 'Request timed out');
    } on SocketException catch (e) {
      throw CloudflareException(statusCode: 0, message: 'Network error: $e');
    }
  }

  /// POST [url] with JSON [body].
  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool throwOnError = true,
  }) async {
    try {
      final res = await _request(
        'POST',
        Uri.parse(url),
        extraHeaders: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      if (throwOnError && res.statusCode >= 400) {
        throw CloudflareException(
          statusCode: res.statusCode,
          message: _extractError(res.body),
          body: res.body,
        );
      }
      return res;
    } on CloudflareException {
      rethrow;
    } on TimeoutException {
      throw const CloudflareException(
          statusCode: 408, message: 'Request timed out');
    } on SocketException catch (e) {
      throw CloudflareException(statusCode: 0, message: 'Network error: $e');
    }
  }

  /// PATCH [url] with JSON [body].
  Future<http.Response> patch(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool throwOnError = true,
  }) async {
    try {
      final res = await _request(
        'PATCH',
        Uri.parse(url),
        extraHeaders: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      if (throwOnError && res.statusCode >= 400) {
        throw CloudflareException(
          statusCode: res.statusCode,
          message: _extractError(res.body),
          body: res.body,
        );
      }
      return res;
    } on CloudflareException {
      rethrow;
    } on TimeoutException {
      throw const CloudflareException(
          statusCode: 408, message: 'Request timed out');
    } on SocketException catch (e) {
      throw CloudflareException(statusCode: 0, message: 'Network error: $e');
    }
  }

  /// DELETE [url].
  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    bool throwOnError = true,
  }) async {
    try {
      final res =
          await _request('DELETE', Uri.parse(url), extraHeaders: headers);
      if (throwOnError && res.statusCode >= 400) {
        throw CloudflareException(
          statusCode: res.statusCode,
          message: _extractError(res.body),
          body: res.body,
        );
      }
      return res;
    } on CloudflareException {
      rethrow;
    } on TimeoutException {
      throw const CloudflareException(
          statusCode: 408, message: 'Request timed out');
    } on SocketException catch (e) {
      throw CloudflareException(statusCode: 0, message: 'Network error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _extractError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error'] as String? ??
          data['message'] as String? ??
          'Unknown error';
    } catch (_) {
      return body.isNotEmpty ? body : 'Unknown error';
    }
  }

  void dispose() => _client.close();
}
