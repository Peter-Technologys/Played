import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Backgrounds ────────────────────────────────────────────────────────
  static const Color background       = Color(0xFF020408);
  static const Color surface          = Color(0xFF080D18);
  static const Color surfaceElevated  = Color(0xFF0D1525);
  static const Color surfaceHighlight = Color(0xFF131E30);
  static const Color border           = Color(0xFF1C2840);
  static const Color borderSubtle     = Color(0xFF0A1020);

  // ── Brand Accents ───────────────────────────────────────────────────
  static const Color accent       = Color(0xFF00E5FF); // Electric Cyan 2027
  static const Color accentViolet = Color(0xFF8B5CF6); // Violet
  static const Color accentPink   = Color(0xFFF472B6);
  static const Color accentGreen  = Color(0xFF34D399);
  static const Color accentAmber  = Color(0xFFFBBF24);

  // ── Glow colours ───────────────────────────────────────────────────
  static const Color glowBlue   = Color(0x5000E5FF);
  static const Color glowViolet = Color(0x508B5CF6);

  // ── Gradient presets ───────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentViolet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [accent, accentViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF080D18), Color(0xFF0D1525)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC020408)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0F6FF);
  static const Color textSecondary = Color(0xFF5A7299);
  static const Color textMuted     = Color(0xFF243040);

  // ── Status ───────────────────────────────────────────────────────────
  static const Color error   = Color(0xFFFF4D6A);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
}
