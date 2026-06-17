import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// PLAYED branded logo — gradient ShaderMask text with neon glow border.
/// Used on splash, onboarding, settings About card, and any screen that needs it.
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
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.08),
            AppColors.accentViolet.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [AppColors.accent, AppColors.accentViolet],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
        child: Text(
          'PLAYED',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white, // ShaderMask overrides this with gradient
            fontFamily: 'Inter',
            letterSpacing: letterSpacing,
          ),
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
