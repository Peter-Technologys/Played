// lib/core/services/api_signer.dart
//
// Signs every outgoing request with HMAC-SHA256 so the Worker can verify
// the request came from the real Otya Player app.
//
// The shared secret (OTYA_STORE_ADMIN_TOKEN) must NEVER be shipped in
// plaintext. Store it using --dart-define at build time:
//
//   flutter build apk --dart-define=OTYA_SECRET=your_token_here
//
// Then read it here with:  const String.fromEnvironment('OTYA_SECRET')

import 'dart:convert';
import 'package:crypto/crypto.dart';

class ApiSigner {
  // Injected at build time — never hardcode the real value here.
  static const _secret = String.fromEnvironment('OTYA_SECRET');

  /// Returns the headers to attach to every API request.
  ///
  /// [method]   HTTP method in uppercase, e.g. 'GET'
  /// [path]     URL path including leading slash, e.g. '/api/theme'
  /// [deviceId] Optional stable device UUID (stored in SharedPreferences)
  static Map<String, String> signedHeaders({
    required String method,
    required String path,
    String? deviceId,
  }) {
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signingString = '$method:$path:$timestamp';

    final key     = utf8.encode(_secret);
    final message = utf8.encode(signingString);
    final hmac    = Hmac(sha256, key);
    final signature = hmac.convert(message).toString();

    return {
      'X-Otya-Timestamp': timestamp,
      'X-Otya-Signature': signature,
      if (deviceId != null) 'X-Otya-Device-Id': deviceId,
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
    };
  }
}
