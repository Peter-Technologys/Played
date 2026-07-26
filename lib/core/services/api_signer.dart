// lib/core/services/api_signer.dart
//
// Signs every outgoing request with HMAC-SHA256 so the Worker can verify
// the request came from the real Otya Player app.
//
// The shared secret must NEVER be shipped in plaintext.
// Build with: flutter build apk --dart-define=OTYA_SECRET=your_token_here

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

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
    if (_secret.isEmpty) {
      debugPrint(
        '[ApiSigner] WARNING: OTYA_SECRET is not set. '
        'Build with --dart-define=OTYA_SECRET=your_token. '
        'All API calls will be rejected by the Worker.',
      );
      // Still proceed — Worker will return 401, which is handled gracefully.
    }

    assert(
      _secret.isNotEmpty,
      'OTYA_SECRET is empty — build with --dart-define=OTYA_SECRET=your_token',
    );

    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final signingString = '$method:$path:$timestamp';

    final key       = utf8.encode(_secret);
    final message   = utf8.encode(signingString);
    final hmac      = Hmac(sha256, key);
    final signature = hmac.convert(message).toString(); // lowercase hex

    return {
      'X-Otya-Timestamp': timestamp,
      'X-Otya-Signature': signature,
      if (deviceId != null && deviceId.isNotEmpty)
        'X-Otya-Device-Id': deviceId,
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
    };
  }
}
