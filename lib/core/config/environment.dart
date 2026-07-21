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

  // ── Website & APK distribution ─────────────────────────────────────────────────────────────────────────────
  // All APK downloads, version checks, and update notifications go through
  // petersmartlink.com (Cloudflare Worker + R2). The old getotya subdomain
  // is no longer used.
  static const String workerUrl           = 'https://petersmartlink.com';
  static const String versionUrl          = '$workerUrl/version';
  static const String latestUrl           = '$workerUrl/latest';
  static const String downloadUrl         = '$workerUrl/download';
  static const String arm64DownloadUrl    = '$workerUrl/apk/arm64';
  static const String arm32DownloadUrl    = '$workerUrl/apk/arm32';

  // ── App Info ─────────────────────────────────────────────────────────────────────────────
  static const String appName             = 'OTYA Player';
  static const String appPackageId        = 'com.otyaplayer.app';
  static const String supportEmail        = 'support@petersmartlink.com';
  static const String websiteUrl          = 'https://petersmartlink.com';
  static const String downloadPageUrl     = 'https://petersmartlink.com/download/otya-player';
}
