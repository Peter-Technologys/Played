/// Compile-time flavor configuration.
///
/// Set via `--dart-define=SELF_UPDATE=true` when building the Huawei flavor.
/// The standard (Google Play) flavor uses the default value of `false`.
///
/// Usage in build commands:
///   Standard:  flutter build apk --flavor standard
///   Huawei:    flutter build apk --flavor huawei --dart-define=SELF_UPDATE=true
class FlavorConfig {
  FlavorConfig._();

  /// Whether in-app APK download and self-install is enabled.
  ///
  /// `true`  → Huawei AppGallery build (self-update allowed).
  /// `false` → Google Play / standard build (updates via Play Store only).
  static const bool selfUpdateEnabled =
      bool.fromEnvironment('SELF_UPDATE', defaultValue: false);
}
