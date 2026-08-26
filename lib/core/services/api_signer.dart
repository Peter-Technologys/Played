/// Compatibility headers for the pre-authenticated-request API.
///
/// OTYA no longer embeds a shared signing secret in the APK. Protected API
/// requests must send the short-lived Bearer token issued by OTYA Auth.
/// This helper remains temporarily for legacy callers that only need common
/// headers; it never creates or embeds a secret.
class ApiSigner {
  static Map<String, String> signedHeaders({
    required String method,
    required String path,
    String? deviceId,
  }) {
    return {
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      if (deviceId != null && deviceId.isNotEmpty) 'X-Otya-Device-Id': deviceId,
    };
  }
}
