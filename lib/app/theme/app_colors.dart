import 'package:flutter/material.dart';

/// Canonical OTYA visual system.
///
/// OTYA uses a deep neutral foundation so local artwork remains the focus.
/// The cyan → blue → violet → pink → orange spectrum is the single branded
/// accent family used by the O mark, onboarding and selected controls.
abstract class AppColors {
  static const Color background = Color(0xFF050611);
  static const Color surface = Color(0xFF0B0D1C);
  static const Color surfaceElevated = Color(0xFF11152A);
  static const Color surfaceHighlight = Color(0xFF191E38);
  static const Color border = Color(0xFF252B4A);
  static const Color borderSubtle = Color(0xFF181D35);

  static const Color accent = Color(0xFF7B4DFF);
  static const Color accentViolet = Color(0xFF8D2BFF);
  static const Color accentPink = Color(0xFFFF2EC4);
  static const Color accentBlue = Color(0xFF3478FF);
  static const Color accentCyan = Color(0xFF16C7FF);
  static const Color accentOrange = Color(0xFFFF8C1E);

  static const Color accentGreen = Color(0xFF41E57A);
  static const Color accentAmber = Color(0xFFFFD34A);

  static const Color glowBlue = Color(0x333478FF);
  static const Color glowViolet = Color(0x3D8D2BFF);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [
      Color(0xFF16C7FF),
      Color(0xFF3478FF),
      Color(0xFF8D2BFF),
      Color(0xFFFF2EC4),
      Color(0xFFFF8C1E),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [
      Color(0xFF16C7FF),
      Color(0xFF3478FF),
      Color(0xFF8D2BFF),
      Color(0xFFFF2EC4),
      Color(0xFFFF8C1E),
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0C0F20), Color(0xFF12162C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xF2050611)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color textPrimary = Color(0xFFF7F7FB);
  static const Color textSecondary = Color(0xFFB4B7C9);
  static const Color textMuted = Color(0xFF777C94);

  static const Color error = Color(0xFFFF5E7A);
  static const Color success = Color(0xFF41E57A);
  static const Color warning = Color(0xFFFFD34A);

  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? border
          : const Color(0xFFE5E5E8);

  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceElevated
          : Colors.white;
}
