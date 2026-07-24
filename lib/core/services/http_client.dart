// lib/core/services/http_client.dart
//
// A single persistent HTTP client reused across all API calls.
// This keeps TCP/TLS connections alive (HTTP Keep-Alive) so each
// subsequent request skips the handshake — much faster on mobile.

import 'package:http/http.dart' as http;

class AppHttpClient {
  AppHttpClient._();
  static final AppHttpClient instance = AppHttpClient._();

  // Persistent client — do NOT create a new one per request.
  final http.Client _client = http.Client();

  http.Client get client => _client;

  /// Convenience: GET with timeout.
  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
  }) =>
      _client.get(uri, headers: headers).timeout(timeout);

  /// Convenience: POST with timeout.
  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 10),
  }) =>
      _client.post(uri, headers: headers, body: body).timeout(timeout);

  void dispose() => _client.close();
}
