import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Canonical in-app OTYA brand lockup.
///
/// The mark is drawn in Flutter so visible product branding never falls back
/// to an old launcher bitmap. Android launcher/adaptive assets are generated
/// separately from the approved master artwork.
class OtyaLogo extends StatelessWidget {
  const OtyaLogo({
    super.key,
    this.fontSize = 30,
    this.letterSpacing = 2.4,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.iconOnly = false,
  });

  final double fontSize;
  final double letterSpacing;
  final double borderRadius;
  final EdgeInsets padding;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final mark = OtyaMark(size: fontSize * 1.18);
    if (iconOnly) return mark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardOf(context).withValues(alpha: .82),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(width: fontSize * .34),
          Text(
            'OTYA',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimaryOf(context),
              fontFamily: 'Inter',
              letterSpacing: letterSpacing,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// OTYA's master in-app symbol: one continuous O / portal loop.
class OtyaMark extends StatelessWidget {
  const OtyaMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    final stroke = size * .18;
    return Semantics(
      label: 'OTYA',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFF00C8FF),
                Color(0xFF315CFF),
                Color(0xFF8A2BFF),
                Color(0xFFFF1BCB),
                Color(0xFFFF7A18),
                Color(0xFFFFD11A),
                Color(0xFF00C8FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3CFF).withValues(alpha: .28),
                blurRadius: size * .28,
                spreadRadius: size * .015,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: size - stroke * 2,
              height: size - stroke * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OtyaFooter extends StatelessWidget {
  const OtyaFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'OTYA · PeterSmart Link',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: .58),
            fontFamily: 'Inter',
            letterSpacing: .3,
          ),
        ),
      );
}
