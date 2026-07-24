/// Appwrite project configuration for OTYA Player.
abstract class Environment {
  // ── Appwrite ─────────────────────────────────────────────────────────────────────────────
  static const String appwriteProjectId   = '6a3011f1003b1a6cc74d';
  static const String appwriteEndpoint    = 'https://nyc.cloud.appwrite.io/v1';

  // ── Appwrite Database ─────────────────────────────────────────────────────────────────────────────
  static const String databaseId          = 'otya-db';

  // ── Appwrite Collections ─────────────────────────────────────────────────────────────────────────────
  static const String playlistsCollection = 'playlists';
  static const String historyCollection   = 'play_history';
  static const String proStatusCollection = 'pro_status';
  static const String releasesCollection  = 'releases';
  static const String devicesCollection   = 'devices';

  // ── Website & APK distribution ────────────────────────────────────────────
  static const String workerUrl           = 'https://petersmartlink.com';
  static const String versionUrl          = '$workerUrl/version';
  static const String latestUrl           = '$workerUrl/latest';
  static const String downloadUrl         = '$workerUrl/download';
  static const String arm64DownloadUrl    = '$workerUrl/apk/arm64';
  static const String arm32DownloadUrl    = '$workerUrl/apk/arm32';

  // ── Cloudflare Worker API (D1-backed, HMAC-authenticated) ───────────────
  static const String checkUpdateUrl      = '$workerUrl/check-update';
  static const String registerDeviceUrl   = '$workerUrl/register-device';
  static const String configsThemeUrl     = '$workerUrl/api/theme';
  static const String apiThemeUrl         = '$workerUrl/api/theme';
  static const String apiVersionUrl       = '$workerUrl/api/version';
  static const String apiDeviceUrl        = '$workerUrl/api/device';
  static const String apiPlaylistsUrl     = '$workerUrl/api/playlists';
  static const String apiHistoryUrl       = '$workerUrl/api/history';
  static const String apiProUrl           = '$workerUrl/api/pro';

  // ── App Info ─────────────────────────────────────────────────────────────────────────────
  static const String appName             = 'OTYA Player';
  static const String appPackageId        = 'com.otyaplayer.app';
  static const String supportEmail        = 'support@petersmartlink.com';
  static const String websiteUrl          = 'https://petersmartlink.com';
  static const String downloadPageUrl     = 'https://petersmartlink.com/download/otya-player';
}
