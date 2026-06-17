import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Backgrounds — deep dark navy matching the logo background ──────────
  static const Color background       = Color(0xFF04060D);
  static const Color surface          = Color(0xFF090E1A);
  static const Color surfaceElevated  = Color(0xFF0F1626);
  static const Color surfaceHighlight = Color(0xFF162035);
  static const Color border           = Color(0xFF1A2540);
  static const Color borderSubtle     = Color(0xFF0D1422);

  // ── Brand Accents — pulled directly from the logo ──────────────────
  // Logo circle: Electric Cyan #00D4FF
  // Logo play triangle: deep dark fill
  static const Color accent       = Color(0xFF00D4FF); // Electric Cyan
  static const Color accentViolet = Color(0xFF7C3AED); // Deep Violet
  static const Color accentPink   = Color(0xFFEC4899);
  static const Color accentGreen  = Color(0xFF10B981);
  static const Color accentAmber  = Color(0xFFF59E0B);

  // ── Glow colours ───────────────────────────────────────────────────
  static const Color glowBlue   = Color(0x4000D4FF);
  static const Color glowViolet = Color(0x407C3AED);

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
    colors: [Color(0xFF090E1A), Color(0xFF0F1626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC04060D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFEEF4FF); // cool white, blue-tinted
  static const Color textSecondary = Color(0xFF5E7399); // muted blue-grey
  static const Color textMuted     = Color(0xFF283347); // very muted

  // ── Status ───────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error   = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
