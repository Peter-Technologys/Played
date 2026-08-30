/// Values that define the installed Otya application and must stay stable
/// across environments. These are safe to compile into the APK.
abstract final class AppContract {
  static const String appName = 'Otya';
  static const String appPackageId = 'com.otyaplayer.app';

  /// Otya's current authentication contract. The server is authoritative;
  /// keeping the client copy centralized prevents UI drift.
  static const int otpLength = 5;
  static const String otpExample = 'A1234';
  static final RegExp otpPattern = RegExp(r'^[A-Z][0-9]{4}$');

  /// Supported app UI locales. Language content belongs in ARB files, not here.
  static const String englishLocale = 'en';
  static const String lugandaLocale = 'lg';
}

/// Public, non-secret configuration that may change between releases or
/// environments. These values can be overridden with --dart-define.
///
/// IMPORTANT: --dart-define is configuration, not secret storage. Anything the
/// mobile app receives at runtime can ultimately be extracted from the APK or
/// process, so private credentials must remain on Cloudflare/server-side only.
abstract final class Environment {
  static const String workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'https://petersmartlink.com',
  );

  static const String publicSiteUrl = String.fromEnvironment(
    'PUBLIC_SITE_URL',
    defaultValue: 'https://petersmartlink.com',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@petersmartlink.com',
  );

  // Compatibility aliases used throughout the current app.
  static const String appName = AppContract.appName;
  static const String appPackageId = AppContract.appPackageId;
  static const String websiteUrl = publicSiteUrl;

  // Canonical online API endpoints. Keep this list small: each online job has
  // one owner, while local playback/scanning continue without these services.
  static const String apiCrashUrl = '$workerUrl/api/crash-report';
  static const String checkUpdateUrl = '$workerUrl/check-update';
  static const String apiVersionUrl = '$workerUrl/api/version';
  static const String apiDeviceUrl = '$workerUrl/api/device';
  static const String apiFeedbackUrl = '$workerUrl/api/feedback';
  static const String onlineMusicUrl = '$workerUrl/api/music/jamendo';
  static const String latestUrl = '$workerUrl/latest';

  // Spotify client ID and redirect URI are public OAuth application metadata,
  // not credentials. The Spotify client secret must never be shipped here.
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
  static const String docsUrl = '$publicSiteUrl/docs';
  static const String downloadPageUrl = '$publicSiteUrl/download/otya-player';

  /// Self-installing APK updates are opt-in. Keep disabled by default so a
  /// release cannot accidentally enable installer behavior.
  static const bool selfUpdateEnabled =
      bool.fromEnvironment('SELF_UPDATE', defaultValue: false);

  static const String appArch =
      String.fromEnvironment('APP_ARCH', defaultValue: 'arm64');
}
