import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Backgrounds — true deep dark with blue tint (matches logo) ──────────
  static const Color background       = Color(0xFF050810); // near-black, blue-tinted
  static const Color surface          = Color(0xFF0C1120); // card surface
  static const Color surfaceElevated  = Color(0xFF131929); // elevated card
  static const Color surfaceHighlight = Color(0xFF1A2235); // hover / selected state
  static const Color border           = Color(0xFF1C2840); // subtle border
  static const Color borderSubtle     = Color(0xFF111827); // very subtle divider

  // ── Brand Accents — Electric Blue + Deep Violet (logo colours) ──────────
  static const Color accent       = Color(0xFF00D4FF); // Electric Blue — primary
  static const Color accentViolet = Color(0xFF7C3AED); // Deep Violet — secondary
  static const Color accentPink   = Color(0xFFEC4899); // Hot Pink — tertiary
  static const Color accentGreen  = Color(0xFF10B981); // Emerald — success
  static const Color accentAmber  = Color(0xFFF59E0B); // Amber — warning

  // ── Glow colours (for BoxShadow) ────────────────────────────────────────
  static const Color glowBlue   = Color(0x3300D4FF); // 20% accent
  static const Color glowViolet = Color(0x337C3AED); // 20% violet

  // ── Gradient presets ─────────────────────────────────────────────────────
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
    colors: [Color(0xFF0C1120), Color(0xFF131929)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC050810)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0F6FF); // slightly blue-white
  static const Color textSecondary = Color(0xFF6B7FA3); // blue-grey
  static const Color textMuted     = Color(0xFF2D3A52); // very muted

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error   = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
