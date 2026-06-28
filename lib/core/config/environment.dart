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
  // Each collection needs these permissions: role:user (read, write)
  static const String playlistsCollection = 'playlists';
  static const String historyCollection   = 'play_history';
  static const String proStatusCollection = 'pro_status';

  // ── App Info ───────────────────────────────────────────────────────────────────
  static const String appName             = 'OTYA Player';
  static const String appVersion          = '1.2.0';
  static const String appPackageId        = 'com.otyaplayer.app';
  static const String supportEmail = 'support@petersmartlink.com';
  static const String websiteUrl   = 'https://petersmartlink.com';
}
