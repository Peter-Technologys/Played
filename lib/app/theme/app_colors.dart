import 'package:flutter/material.dart';

/// OTYA visual system.
///
/// Product chrome stays quiet so artwork, video thumbnails and user content
/// provide most of the color. Violet is the primary OTYA accent; secondary
/// hues are reserved for status, media artwork and restrained emphasis.
abstract class AppColors {
  static const Color background       = Color(0xFF0F0F10);
  static const Color surface          = Color(0xFF151516);
  static const Color surfaceElevated  = Color(0xFF1B1B1D);
  static const Color surfaceHighlight = Color(0xFF232326);
  static const Color border           = Color(0xFF2C2C30);
  static const Color borderSubtle     = Color(0xFF232326);

  static const Color accent       = Color(0xFF8173F2);
  static const Color accentViolet = Color(0xFF8173F2);
  static const Color accentPink   = Color(0xFFA979D7);
  static const Color accentBlue   = Color(0xFF668FE8);
  static const Color accentCyan   = Color(0xFF6DAFC9);
  static const Color accentOrange = Color(0xFFD69A68);

  static const Color accentGreen = Color(0xFF4FB98A);
  static const Color accentAmber = Color(0xFFD8A84F);

  static const Color glowBlue   = Color(0x1F668FE8);
  static const Color glowViolet = Color(0x248173F2);

  /// Restrained product accent. Large surfaces should normally use neutral
  /// colors; this is for focused actions and small branded details.
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF8173F2), Color(0xFF668FE8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [Color(0xFF668FE8), Color(0xFF8173F2), Color(0xFFA979D7)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF171718), Color(0xFF1B1B1D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xF20F0F10)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color textPrimary   = Color(0xFFF3F3F4);
  static const Color textSecondary = Color(0xFFA5A5AA);
  static const Color textMuted     = Color(0xFF747479);

  static const Color error   = Color(0xFFFF6478);
  static const Color success = Color(0xFF4FB98A);
  static const Color warning = Color(0xFFD8A84F);

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
