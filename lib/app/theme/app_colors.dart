import 'package:flutter/material.dart';

/// OTYA master visual system.
///
/// The interface stays theme-aware while using the approved OTYA identity:
/// deep navy/black surfaces with electric cyan, blue, violet, magenta and
/// warm orange highlights. Semantic colors remain reserved for status.
abstract class AppColors {
  static const Color background       = Color(0xF2050618);
  static const Color surface          = Color(0xE90A0B22);
  static const Color surfaceElevated  = Color(0xF20F102A);
  static const Color surfaceHighlight = Color(0xF5161738);
  static const Color border           = Color(0x80353670);
  static const Color borderSubtle     = Color(0x66232555);

  static const Color accent       = Color(0xFF8B2CFF);
  static const Color accentViolet = Color(0xFF8B2CFF);
  static const Color accentPink   = Color(0xFFFF20C8);
  static const Color accentBlue   = Color(0xFF006CFF);
  static const Color accentCyan   = Color(0xFF00D9FF);
  static const Color accentOrange = Color(0xFFFF8A00);

  static const Color accentGreen = Color(0xFF22D98B);
  static const Color accentAmber = Color(0xFFFFB020);

  static const Color glowBlue   = Color(0x4400B8FF);
  static const Color glowViolet = Color(0x448B2CFF);

  /// Primary OTYA action gradient used by buttons, selected states and
  /// progress accents. Avoid using it as large body text for readability.
  static const LinearGradient accentGradient = LinearGradient(
    colors: [
      Color(0xFF00C8FF),
      Color(0xFF006CFF),
      Color(0xFF8B2CFF),
      Color(0xFFFF20C8),
    ],
    stops: [0.0, 0.32, 0.67, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Full logo-family spectrum for hero art and restrained decorative use.
  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [
      Color(0xFF00D9FF),
      Color(0xFF006CFF),
      Color(0xFF8B2CFF),
      Color(0xFFFF20C8),
      Color(0xFFFF8A00),
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xF20B0C24), Color(0xF2161234)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xF2050618)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color textPrimary   = Color(0xFFF9F9FF);
  static const Color textSecondary = Color(0xFFB4B5CA);
  static const Color textMuted     = Color(0xFF777994);

  static const Color error   = Color(0xFFFF4F78);
  static const Color success = Color(0xFF22D98B);
  static const Color warning = Color(0xFFFFB020);

  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? border
          : const Color(0xFFE2E3ED);

  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceElevated
          : Colors.white;
}
