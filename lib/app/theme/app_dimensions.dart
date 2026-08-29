/// Shared OTYA layout and motion tokens.
///
/// Keep these values deliberately small and predictable. OTYA is a media app:
/// artwork and content should dominate the screen, not oversized chrome.
abstract final class AppDimensions {
  AppDimensions._();

  // Window classes.
  static const double compactMax = 599;
  static const double mediumMin = 600;
  static const double expandedMin = 840;

  // Primary chrome.
  static const double bottomNavHeight = 62;
  static const double navigationRailWidth = 76;
  static const double topBarHeight = 56;

  // Touch/accessibility.
  static const double minimumTouchTarget = 48;

  // Spacing.
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  // Radius.
  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 18;
  static const double radiusXLarge = 24;
  static const double radiusSheet = 28;

  // Motion.
  static const Duration motionFast = Duration(milliseconds: 140);
  static const Duration motionStandard = Duration(milliseconds: 200);
  static const Duration motionEmphasized = Duration(milliseconds: 280);
}
