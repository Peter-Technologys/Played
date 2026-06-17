import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// OTYA Player branded logo — icon + gradient OTYA PLAYER text.
class PlayedLogo extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;
  final double borderRadius;
  final EdgeInsets padding;
  final bool iconOnly;

  const PlayedLogo({
    super.key,
    this.fontSize = 36,
    this.letterSpacing = 6,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Image.asset(
        'assets/icons/play_store_512.png',
        width: fontSize * 1.4,
        height: fontSize * 1.4,
        errorBuilder: (_, __, ___) => _gradientText(),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentViolet.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.accentViolet.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentViolet.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/play_store_512.png',
            width: fontSize * 1.15,
            height: fontSize * 1.15,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          SizedBox(width: fontSize * 0.35),
          _gradientText(),
        ],
      ),
    );
  }

  Widget _gradientText() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        'OTYA PLAYER',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFamily: 'Inter',
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}

/// "from OTYA" footer.
class PlayedFooter extends StatelessWidget {
  const PlayedFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'OTYA Player — Otya? Play.',
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
