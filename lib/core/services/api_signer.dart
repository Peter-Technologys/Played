/// Shared request headers for OTYA backend calls that do not need a body
/// signature. OTYA never embeds a shared server secret in the APK.
///
/// Protected endpoints authenticate with short-lived Bearer tokens where
/// required; this helper only centralizes safe common headers and the optional
/// device identifier used by existing backend routes.
class ApiSigner {
  static Map<String, String> signedHeaders({
    required String method,
    required String path,
    String? deviceId,
  }) {
    return {
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      if (deviceId != null && deviceId.isNotEmpty)
        'X-Otya-Device-Id': deviceId,
    };
  }
}
