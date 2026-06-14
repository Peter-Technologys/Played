import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Shared PLAYED branded logo box — used on splash, permission screen,
/// settings About card, onboarding, and any other screen that needs it.
///
/// Usage:
///   const PlayedLogo()              // default size
///   const PlayedLogo(fontSize: 22)  // smaller variant for cards
class PlayedLogo extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;
  final double borderRadius;
  final EdgeInsets padding;

  const PlayedLogo({
    super.key,
    this.fontSize = 36,
    this.letterSpacing = 6,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppColors.accent.withValues(alpha: 0.05),
      ),
      child: Text(
        'PLAYED',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          fontFamily: 'Inter',
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}

/// "from PeterSmart Technologies" footer — shared across all screens.
class PlayedFooter extends StatelessWidget {
  const PlayedFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'from PeterSmart Technologies',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
