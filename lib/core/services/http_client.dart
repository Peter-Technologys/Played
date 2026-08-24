// lib/core/services/http_client.dart
//
// A single persistent HTTP client reused across all API calls.
// This keeps TCP/TLS connections alive (HTTP Keep-Alive) so each
// subsequent request skips the handshake — much faster on mobile.
//
// Retry policy: up to 2 retries for 5xx responses and network errors,
// with 1 s backoff after the first failure and 2 s after the second.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppHttpClient {
  AppHttpClient._();
  static final AppHttpClient instance = AppHttpClient._();

  // Persistent client — do NOT create a new one per request.
  final http.Client _client = http.Client();

  http.Client get client => _client;

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const int _maxRetries = 2;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  /// Returns true for status codes that should trigger a retry.
  static bool _isRetryableStatus(int statusCode) =>
      statusCode >= 500 && statusCode < 600;

  /// Returns true for exceptions that should trigger a retry.
  static bool _isRetryableException(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException;

  /// Convenience: GET with connect + receive timeouts and retry.
  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = _receiveTimeout,
  }) =>
      _withRetry(() => _client.get(uri, headers: headers).timeout(timeout));

  /// Convenience: POST with connect + receive timeouts and retry.
  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _receiveTimeout,
  }) =>
      _withRetry(
        () => _client.post(uri, headers: headers, body: body).timeout(timeout),
      );

  /// Executes [request] with up to [_maxRetries] retries on 5xx or network
  /// errors. Uses exponential-ish backoff: 1 s, then 2 s.
  Future<http.Response> _withRetry(
    Future<http.Response> Function() request,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await request().timeout(_connectTimeout);
        if (_isRetryableStatus(response.statusCode) &&
            attempt < _maxRetries) {
          debugPrint(
            '[AppHttpClient] ${response.statusCode} — retrying '
            '(attempt ${attempt + 1}/$_maxRetries)…',
          );
          await Future<void>.delayed(_retryDelays[attempt]);
          attempt++;
          continue;
        }
        return response;
      } catch (e) {
        if (_isRetryableException(e) && attempt < _maxRetries) {
          debugPrint(
            '[AppHttpClient] Network error ($e) — retrying '
            '(attempt ${attempt + 1}/$_maxRetries)…',
          );
          await Future<void>.delayed(_retryDelays[attempt]);
          attempt++;
          continue;
        }
        rethrow;
      }
    }
  }

  void dispose() => _client.close();
}
