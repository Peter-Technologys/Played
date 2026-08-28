abstract class Environment {
  // Production-safe default. CI can still override this with
  // --dart-define=WORKER_URL=https://... for staging or another environment.
  // A localhost fallback caused release builds without injected variables to
  // silently point at a server that does not exist on the user's phone.
  static const String workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'https://petersmartlink.com',
  );

  static const String umbrellaName = 'OTYA';
  static const String productName = 'OTYA Player';

  static const String apiSyncUrl      = '$workerUrl/api/sync';
  static const String apiCrashUrl     = '$workerUrl/api/crash-report';
  static const String checkUpdateUrl  = '$workerUrl/check-update';
  static const String apiVersionUrl   = '$workerUrl/api/version';
  static const String apiDeviceUrl    = '$workerUrl/api/device';
  static const String apiPlaylistsUrl = '$workerUrl/api/playlists';
  static const String apiHistoryUrl   = '$workerUrl/api/history';
  static const String apiProUrl       = '$workerUrl/api/pro';
  static const String apiFeedbackUrl  = '$workerUrl/api/feedback';

  static const String latestUrl = '$workerUrl/latest';

  static const String arm64DownloadUrl = '$workerUrl/apk/arm64';
  static const String arm32DownloadUrl = '$workerUrl/apk/arm32';
  static const String downloadUrl      = '$workerUrl/download/otya-player';

  static const String appName      = productName;
  static const String appPackageId = 'com.otyaplayer.app';
  static const String supportEmail = 'support@petersmartlink.com';
  static const String websiteUrl   = workerUrl;
  static const String documentsUrl = '$workerUrl/documents';
  static const String downloadPageUrl = '$workerUrl/download/otya-player';

  /// Self-installing APK updates are opt-in. Keep disabled by default so a
  /// Play-distributed build cannot accidentally ship the installer flow.
  static const bool selfUpdateEnabled =
      bool.fromEnvironment('SELF_UPDATE', defaultValue: false);

  static const String appArch =
      String.fromEnvironment('APP_ARCH', defaultValue: 'arm64');
}
