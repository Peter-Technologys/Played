import 'package:flutter/material.dart';

/// PeterSmart Link / OTYA master visual system.
///
/// The approved product concept uses near-black foundations, layered charcoal
/// surfaces and one purple brand family. Media artwork supplies the rich colour.
/// Semantic green/amber/red are reserved for status only.
abstract class AppColors {
  static const Color background       = Color(0xFF08080B);
  static const Color surface          = Color(0xB8101014);
  static const Color surfaceElevated  = Color(0xC716161D);
  static const Color surfaceHighlight = Color(0xD61D1D27);
  static const Color border           = Color(0x802A2A35);
  static const Color borderSubtle     = Color(0x66202029);

  // Compatibility aliases deliberately remain in one purple family so older
  // screens cannot drift back into cyan/pink/rainbow decorative styling.
  static const Color accent       = Color(0xFF8B5CF6);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentPink   = Color(0xFFA78BFA);

  static const Color accentGreen = Color(0xFF4ADE80);
  static const Color accentAmber = Color(0xFFFBBF24);

  static const Color glowBlue   = Color(0x288B5CF6);
  static const Color glowViolet = Color(0x308B5CF6);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF111116), Color(0xFF181820)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xE608080B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color textPrimary   = Color(0xFFF7F7FB);
  static const Color textSecondary = Color(0xFFA4A4B3);
  static const Color textMuted     = Color(0xFF676776);

  static const Color error   = Color(0xFFFF5D73);
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);

  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? border
          : const Color(0xFFE5E7EB);

  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceElevated
          : Colors.white;
}
