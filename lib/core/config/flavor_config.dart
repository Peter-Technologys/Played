/// Compile-time flavor configuration.
///
/// Set via `--dart-define=FLAVOR=standard` (Play Store) or
/// `--dart-define=FLAVOR=huawei` (Huawei AppGallery).
///
/// The standard (Play Store) flavor disables the self-update mechanism
/// because Google Play does not allow apps to download and install their
/// own APK updates outside of the Play Store.
class FlavorConfig {
  FlavorConfig._();

  /// The current build flavor, read from the compile-time constant.
  /// Defaults to 'standard' if not set.
  static const String flavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'standard');

  /// Whether the app is allowed to download and install its own APK updates.
  /// - `false` for the `standard` (Google Play) flavor — Play Store policy.
  /// - `true`  for the `huawei` (Huawei AppGallery) flavor.
  static const bool selfUpdateEnabled = flavor == 'huawei';
}
