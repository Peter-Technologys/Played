/// Compile-time flavor configuration.
///
/// selfUpdateEnabled defaults to true so the in-app update checker works
/// for sideloaded APKs out of the box.
/// Set --dart-define=SELF_UPDATE=false for Google Play Store builds.
class FlavorConfig {
  FlavorConfig._();

  /// Whether in-app APK download and self-install is enabled.
  /// Default: true (sideload / direct distribution).
  static const bool selfUpdateEnabled =
      bool.fromEnvironment('SELF_UPDATE', defaultValue: true);
}
