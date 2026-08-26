abstract class Environment {
  // ── Website & Worker base ─────────────────────────────────────────────────
  //
  // Injected at build time via --dart-define=WORKER_URL=https://...
  // NEVER hardcode the production URL here — use the CI/CD variable.
  // The fallback is intentionally a localhost address so any accidental
  // non-injected build fails fast rather than silently hitting production.
  static const String workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'http://localhost:8787',
  );

  // ── API endpoints (all HMAC-authenticated) ────────────────────────────────
  static const String apiSyncUrl      = '$workerUrl/api/sync';
  static const String apiCrashUrl     = '$workerUrl/api/crash-report';
  static const String checkUpdateUrl  = '$workerUrl/check-update';
  static const String apiVersionUrl   = '$workerUrl/api/version';
  static const String apiDeviceUrl    = '$workerUrl/api/device';
  static const String apiPlaylistsUrl = '$workerUrl/api/playlists';
  static const String apiHistoryUrl   = '$workerUrl/api/history';
  static const String apiProUrl       = '$workerUrl/api/pro';
  static const String apiFeedbackUrl  = '$workerUrl/api/feedback';

  // ── Public version endpoint (no auth — used by update checker) ─────────────
  static const String latestUrl = '$workerUrl/latest';

  // ── APK download ──────────────────────────────────────────────────────────
  static const String arm64DownloadUrl = '$workerUrl/apk/arm64';
  static const String arm32DownloadUrl = '$workerUrl/apk/arm32';
  static const String downloadUrl      = '$workerUrl/download/otya-player';

  // ── App info ──────────────────────────────────────────────────────────────
  static const String appName         = 'OTYA Player';
  static const String appPackageId    = 'com.otyaplayer.app';
  static const String supportEmail    = 'support@petersmartlink.com';
  // websiteUrl and downloadPageUrl are derived from workerUrl so they are
  // also never hardcoded.
  static const String websiteUrl      = workerUrl;
  static const String downloadPageUrl = '$workerUrl/download/otya-player';

  // ── Build-time flags ──────────────────────────────────────────────────────
  /// Whether in-app APK download and self-install is enabled.
  /// Set --dart-define=SELF_UPDATE=false for Google Play Store builds.
  static const bool selfUpdateEnabled =
      bool.fromEnvironment('SELF_UPDATE', defaultValue: true);

  /// ABI injected at build time via --dart-define=APP_ARCH=arm64.
  static const String appArch =
      String.fromEnvironment('APP_ARCH', defaultValue: 'arm64');
}
