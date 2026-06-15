/// Appwrite project configuration for PLAYED.
///
/// This project is completely isolated from all other PeterSmart apps.
/// Each app has its own Appwrite project — zero cross-contamination.
///
/// Appwrite Dashboard:
/// https://cloud.appwrite.io/console/project-6a3011f1003b1a6cc74d
abstract class Environment {
  // ── Appwrite ────────────────────────────────────────────────────────────
  static const String appwriteProjectId   = '6a3011f1003b1a6cc74d';
  static const String appwriteProjectName = 'PLAYED server';
  static const String appwriteEndpoint    = 'https://nyc.cloud.appwrite.io/v1';

  // ── Appwrite Database IDs ───────────────────────────────────────────────
  // Create in Appwrite Dashboard → Databases
  static const String databaseId          = 'played-db';

  // ── Appwrite Collection IDs ─────────────────────────────────────────────
  // Create in Appwrite Dashboard → Databases → played-db
  static const String playlistsCollection = 'playlists';
  static const String historyCollection   = 'play_history';
  static const String proStatusCollection = 'pro_status';

  // ── Appwrite Storage Bucket IDs ─────────────────────────────────────────
  // Create in Appwrite Dashboard → Storage
  static const String stemsBucketId       = 'stems';
  static const String backupBucketId      = 'backups';

  // ── App Info ────────────────────────────────────────────────────────────
  static const String appName             = 'PLAYED';
  static const String appVersion          = '1.2.0';
  static const String appPackageId        = 'com.petersmart.played';
  static const String supportEmail        = 'dev@petersmartlink.com';
}
