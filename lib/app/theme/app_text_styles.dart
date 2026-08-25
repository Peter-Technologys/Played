import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract class AppTextStyles {
  static const String _bodyFont = 'Inter';

  // ── Display / Headline / Title — Inter ───────────────────────────────────

  /// Large display heading — Inter, 26sp
  static TextStyle get heading1 => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  /// Section heading — Inter, 18sp
  static TextStyle get heading2 => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// Sub-heading — Inter, 15sp
  static TextStyle get heading3 => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// Screen title (AppBar / tab header) — Inter, 20sp
  static TextStyle get title => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  // ── Body / Sub-text — Inter ───────────────────────────────────────────────

  static const TextStyle body = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.black,
    letterSpacing: 0.2,
  );
}
