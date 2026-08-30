abstract class Environment {
  // Production-safe default. CI can still override this with
  // --dart-define=WORKER_URL=https://... for staging or another environment.
  // Local playback must never depend on this URL being reachable.
  static const String workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'https://petersmartlink.com',
  );

  static const String appName = 'OTYA';
  static const String appPackageId = 'com.otyaplayer.app';

  // Canonical online API endpoints. Keep this list small: each online job has
  // one owner, while local playback/scanning continue without these services.
  static const String apiCrashUrl = '$workerUrl/api/crash-report';
  static const String checkUpdateUrl = '$workerUrl/check-update';
  static const String apiVersionUrl = '$workerUrl/api/version';
  static const String apiDeviceUrl = '$workerUrl/api/device';
  static const String apiFeedbackUrl = '$workerUrl/api/feedback';
  static const String onlineMusicUrl = '$workerUrl/api/music/jamendo';
  static const String latestUrl = '$workerUrl/latest';

  // Spotify's client ID is public application configuration, not a secret.
  // Keep client secrets server-side only. The redirect URI must be allowlisted
  // in the Spotify developer dashboard before OAuth can be enabled.
  static const String spotifyClientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: '',
  );
  static const String spotifyRedirectUri = String.fromEnvironment(
    'SPOTIFY_REDIRECT_URI',
    defaultValue: 'https://petersmartlink.com/auth/spotify/callback',
  );

  static const String arm64DownloadUrl = '$workerUrl/apk/arm64';
  static const String arm32DownloadUrl = '$workerUrl/apk/arm32';
  static const String downloadUrl = '$workerUrl/download/otya-player';

  static const String supportEmail = 'support@petersmartlink.com';
  static const String websiteUrl = workerUrl;
  static const String docsUrl = '$workerUrl/docs';
  static const String downloadPageUrl = '$workerUrl/download/otya-player';

  /// Self-installing APK updates are opt-in. Keep disabled by default so a
  /// Play-distributed build cannot accidentally ship the installer flow.
  static const bool selfUpdateEnabled =
      bool.fromEnvironment('SELF_UPDATE', defaultValue: false);

  static const String appArch =
      String.fromEnvironment('APP_ARCH', defaultValue: 'arm64');
}
