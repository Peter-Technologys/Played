import 'package:flutter/material.dart';

abstract class AppColors {
  // Backgrounds — deeper, richer darks
  static const Color background    = Color(0xFF05080F);
  static const Color surface       = Color(0xFF0D1117);
  static const Color surfaceElevated = Color(0xFF161B27);
  static const Color border        = Color(0xFF1E2736);
  static const Color borderSubtle  = Color(0xFF141A24);

  // Neon Accents
  static const Color accent        = Color(0xFF00D4FF); // Electric Blue
  static const Color accentViolet  = Color(0xFF7C3AED); // Deep Violet
  static const Color accentPink    = Color(0xFFEC4899); // Hot Pink
  static const Color accentGreen   = Color(0xFF10B981); // Emerald

  // Gradient presets
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentViolet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0D1117), Color(0xFF161B27)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC05080F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Text
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted     = Color(0xFF374151);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error   = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
