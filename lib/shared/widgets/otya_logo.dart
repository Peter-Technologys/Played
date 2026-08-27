import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// OTYA brand lockup used inside the app.
///
/// This deliberately avoids the old cyan gradient and legacy Play Store asset.
/// It is a lightweight in-app mark until the final exported brand artwork is
/// added to the Android/iOS/store asset pipeline.
class OtyaLogo extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;
  final double borderRadius;
  final EdgeInsets padding;
  final bool iconOnly;

  const OtyaLogo({
    super.key,
    this.fontSize = 36,
    this.letterSpacing = 4,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final mark = _OtyaMark(size: fontSize * 1.18);
    if (iconOnly) return mark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            SizedBox(width: fontSize * 0.34),
            Text(
              'OTYA',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
                letterSpacing: letterSpacing,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtyaMark extends StatelessWidget {
  final double size;
  const _OtyaMark({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(size * .30),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: .18),
              blurRadius: size * .38,
              offset: Offset(0, size * .12),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * .55,
            height: size * .55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: size * .07),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: size * .36,
            ),
          ),
        ),
      );
}

class OtyaFooter extends StatelessWidget {
  const OtyaFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'OTYA • by PeterSmart Link',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          fontFamily: 'Inter',
          letterSpacing: .4,
        ),
      ),
    );
  }
}
