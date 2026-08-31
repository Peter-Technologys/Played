import 'package:flutter/material.dart';

/// Canonical Otya visual system.
///
/// Otya uses a deep neutral foundation with one strong product blue. The
/// blue/red/yellow trio belongs to the Otya identity and Otya AI. Older violet,
/// pink, cyan and orange names remain as compatibility aliases so existing
/// screens do not invent a second brand palette while they are migrated.
abstract class AppColors {
  static const Color background = Color(0xFF080B12);
  static const Color surface = Color(0xFF0E131D);
  static const Color surfaceElevated = Color(0xFF141B27);
  static const Color surfaceHighlight = Color(0xFF1B2534);
  static const Color border = Color(0xFF283444);
  static const Color borderSubtle = Color(0xFF1B2635);

  // Core Otya identity.
  static const Color brandBlue = Color(0xFF2979FF);
  static const Color brandRed = Color(0xFFFF3B30);
  static const Color brandYellow = Color(0xFFFFD60A);

  static const Color accent = brandBlue;
  static const Color accentBlue = brandBlue;
  static const Color accentCyan = Color(0xFF4A93FF);
  static const Color accentViolet = Color(0xFF2367E6);
  static const Color accentPink = brandRed;
  static const Color accentOrange = Color(0xFFFF8A32);

  static const Color accentGreen = Color(0xFF39D98A);
  static const Color accentAmber = brandYellow;

  static const Color glowBlue = Color(0x332979FF);
  static const Color glowViolet = Color(0x262979FF);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF4A93FF), brandBlue, Color(0xFF1767E8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [Color(0xFF4A93FF), brandBlue, Color(0xFF1767E8)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0E131D), Color(0xFF141B27)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xF2080B12)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color textPrimary = Color(0xFFF7F9FC);
  static const Color textSecondary = Color(0xFFB3BDCC);
  static const Color textMuted = Color(0xFF7F8A9B);

  static const Color error = Color(0xFFFF5B52);
  static const Color success = Color(0xFF39D98A);
  static const Color warning = brandYellow;

  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? border
          : const Color(0xFFE2E7EE);

  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceElevated
          : Colors.white;
}
