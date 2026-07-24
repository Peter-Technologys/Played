abstract class Environment {
  // ── Website & Worker base ─────────────────────────────────────────────────
  static const String workerUrl        = 'https://petersmartlink.com';

  // ── API endpoints (all HMAC-authenticated) ────────────────────────────────
  static const String checkUpdateUrl    = '$workerUrl/check-update';
  static const String registerDeviceUrl = '$workerUrl/register-device';
  static const String apiThemeUrl       = '$workerUrl/api/theme';
  static const String apiVersionUrl     = '$workerUrl/api/version';
  static const String apiDeviceUrl      = '$workerUrl/api/device';
  static const String apiPlaylistsUrl   = '$workerUrl/api/playlists';
  static const String apiHistoryUrl     = '$workerUrl/api/history';
  static const String apiProUrl         = '$workerUrl/api/pro';
  static const String apiFeedbackUrl    = '$workerUrl/api/feedback';
  static const String apiRatingsUrl     = '$workerUrl/api/ratings';

  // ── Public version endpoints (no auth — used by update checker) ───────────
  static const String latestUrl         = '$workerUrl/latest';
  static const String versionUrl        = '$workerUrl/api/version';

  // ── APK download ──────────────────────────────────────────────────────────
  static const String arm64DownloadUrl = '$workerUrl/apk/arm64';
  static const String arm32DownloadUrl = '$workerUrl/apk/arm32';
  static const String downloadUrl      = '$workerUrl/download/otya-player';

  // ── App info ──────────────────────────────────────────────────────────────
  static const String appName          = 'OTYA Player';
  static const String appPackageId     = 'com.otyaplayer.app';
  static const String supportEmail     = 'support@petersmartlink.com';
  static const String websiteUrl       = 'https://petersmartlink.com';
  static const String downloadPageUrl  = 'https://petersmartlink.com/download/otya-player';
}
