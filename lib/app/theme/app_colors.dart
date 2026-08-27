import 'package:flutter/material.dart';

/// PeterSmart Link / OTYA visual system.
///
/// This palette intentionally follows the approved product concept: near-black
/// foundations, layered charcoal surfaces, one restrained purple brand family,
/// bright readable type, and media artwork as the main source of colour.
/// Keep semantic status colours only for actual success/warning/error states.
abstract class AppColors {
  // ── Foundations ────────────────────────────────────────────────────────
  static const Color background       = Color(0xFF08080B);
  static const Color surface          = Color(0xFF101014);
  static const Color surfaceElevated  = Color(0xFF16161D);
  static const Color surfaceHighlight = Color(0xFF1D1D27);
  static const Color border           = Color(0xFF2A2A35);
  static const Color borderSubtle     = Color(0xFF202029);

  // ── PeterSmart Link / OTYA brand ─────────────────────────────────────
  // `accent` remains the compatibility alias used throughout the app.
  static const Color accent       = Color(0xFF8B5CF6);
  static const Color accentViolet = Color(0xFFA855F7);
  static const Color accentPink   = Color(0xFFC084FC);

  // Semantic colours only — do not use these as decorative screen colours.
  static const Color accentGreen  = Color(0xFF4ADE80);
  static const Color accentAmber  = Color(0xFFFBBF24);

  // ── Glow / depth ──────────────────────────────────────────────────────
  static const Color glowBlue   = Color(0x408B5CF6); // legacy alias
  static const Color glowViolet = Color(0x508B5CF6);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient accentGradientDiag = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
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

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF7F7FB);
  static const Color textSecondary = Color(0xFFA4A4B3);
  static const Color textMuted     = Color(0xFF676776);

  // ── Status ────────────────────────────────────────────────────────────
  static const Color error   = Color(0xFFFF5D73);
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);

  // ── Theme-aware helpers ───────────────────────────────────────────────
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
