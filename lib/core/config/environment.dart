/// Appwrite project configuration for OTYA Player.
abstract class Environment {
  // ── Appwrite ───────────────────────────────────────────────────────────────────
  static const String appwriteProjectId   = '6a3011f1003b1a6cc74d';
  static const String appwriteEndpoint    = 'https://nyc.cloud.appwrite.io/v1';

  // ── Appwrite Database ─────────────────────────────────────────────────────────
  // Create in Appwrite Dashboard → Databases
  static const String databaseId          = 'otya-db';

  // ── Appwrite Collections ──────────────────────────────────────────────────────
  // Create in Appwrite Dashboard → Databases → otya-db
  static const String playlistsCollection = 'playlists';
  static const String historyCollection   = 'play_history';
  static const String proStatusCollection = 'pro_status';

  // ── Update / Release tracking ─────────────────────────────────────────────────
  // Collection: 'releases'
  //   Attributes: version(string), versionCode(integer), date(string),
  //               changelog(string), arm64Url(string), arm32Url(string),
  //               downloadUrl(string), minSdk(integer), targetSdk(integer)
  //   Permissions: Any (read), Users (write) — CI writes via server API key
  static const String releasesCollection  = 'releases';

  // Collection: 'devices'
  //   Attributes: deviceId(string), userId(string, optional), appVersion(string),
  //               versionCode(integer), abi(string), platform(string),
  //               registeredAt(string), lastSeenAt(string)
  //   Permissions: Any (create), Users (read/update own)
  static const String devicesCollection   = 'devices';

  // ── Cloudflare Worker ─────────────────────────────────────────────────────────
  static const String workerUrl           = 'https://getotya.petersmartlink.com';
  static const String versionUrl          = '$workerUrl/version';
  static const String latestUrl           = '$workerUrl/latest';
  static const String downloadUrl         = '$workerUrl/download';
  static const String arm64DownloadUrl    = '$workerUrl/apk/arm64';
  static const String arm32DownloadUrl    = '$workerUrl/apk/arm32';

  // ── App Info ───────────────────────────────────────────────────────────────────
  static const String appName             = 'OTYA Player';
  static const String appPackageId        = 'com.otyaplayer.app';
  static const String supportEmail        = 'support@petersmartlink.com';
  static const String websiteUrl          = 'https://petersmartlink.com';
  static const String downloadPageUrl     = 'https://petersmartlink.com/download/otya-player';
}
