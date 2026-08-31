/// Shared Otya layout and motion tokens.
///
/// These values follow the current Material 3 / Material 3 Expressive direction:
/// comfortable touch targets, clearer hierarchy, larger primary chrome and a
/// more expressive shape scale. Media artwork still owns the screen.
abstract final class AppDimensions {
  AppDimensions._();

  // Window classes.
  static const double compactMax = 599;
  static const double mediumMin = 600;
  static const double expandedMin = 840;

  // Primary chrome.
  static const double bottomNavHeight = 72;
  static const double navigationRailWidth = 88;
  static const double topBarHeight = 64;

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
  static const double space40 = 40;

  // Material 3 expressive shape scale.
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusXLarge = 32;
  static const double radiusSheet = 32;
  static const double radiusPill = 999;

  // Motion.
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionStandard = Duration(milliseconds: 250);
  static const Duration motionEmphasized = Duration(milliseconds: 400);
}
