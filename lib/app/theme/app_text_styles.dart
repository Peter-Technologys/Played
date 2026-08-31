import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Otya typography follows the Material 3 hierarchy while keeping Inter as the
/// product typeface. Large titles are intentionally stronger and body copy is
/// slightly more open for modern Android readability.
abstract class AppTextStyles {
  static const String _font = 'Inter';

  static TextStyle get display => const TextStyle(
        fontFamily: _font,
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading1 => const TextStyle(
        fontFamily: _font,
        fontSize: 32,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading2 => const TextStyle(
        fontFamily: _font,
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading3 => const TextStyle(
        fontFamily: _font,
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get title => const TextStyle(
        fontFamily: _font,
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        color: AppColors.textPrimary,
      );

  static const TextStyle body = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.1,
  );
}
