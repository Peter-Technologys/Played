import 'package:flutter/material.dart';

/// Canonical Otya visual system.
///
/// The current Otya product mark is built around luminous cyan flowing into a
/// strong electric blue on a near-black/navy surface. Functional status colors
/// remain separate so success, warnings and destructive actions stay clear.
abstract class AppColors {
  static const Color background = Color(0xFF050812);
  static const Color surface = Color(0xFF0A1020);
  static const Color surfaceElevated = Color(0xFF10182A);
  static const Color surfaceHighlight = Color(0xFF17233A);
  static const Color border = Color(0xFF213454);
  static const Color borderSubtle = Color(0xFF152640);

  // Core Otya product identity, sampled from the current cyan/blue mark.
  static const Color brandCyan = Color(0xFF27E8FF);
  static const Color brandBlue = Color(0xFF126BFF);
  static const Color brandDeepBlue = Color(0xFF173BFF);

  // Functional / assistant colors retained for compatibility and meaning.
  static const Color brandRed = Color(0xFFFF3B30);
  static const Color brandYellow = Color(0xFFFFD60A);

  static const Color accent = brandBlue;
  static const Color accentBlue = brandBlue;
  static const Color accentCyan = brandCyan;
  static const Color accentViolet = brandDeepBlue;
  static const Color accentPink = brandRed;
  static const Color accentOrange = Color(0xFFFF8A32);

  static const Color accentGreen = Color(0xFF39D98A);
  static const Color accentAmber = brandYellow;

  static const Color glowBlue = Color(0x3D126BFF);
  static const Color glowViolet = Color(0x3027E8FF);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [brandCyan, brandBlue, brandDeepBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [brandCyan, brandBlue, brandDeepBlue],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0A1020), Color(0xFF10182A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xF2050812)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color textPrimary = Color(0xFFF7FAFF);
  static const Color textSecondary = Color(0xFFB5C2D6);
  static const Color textMuted = Color(0xFF7E90AA);

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