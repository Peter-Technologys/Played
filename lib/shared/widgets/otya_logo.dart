import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Canonical in-app OTYA brand lockup.
/// The same artwork is used for launcher generation and visible product branding.
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
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(fontSize * .32),
      child: Image.asset(
        'assets/icons/play_store_512.png',
        width: fontSize * 1.18,
        height: fontSize * 1.18,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
    if (iconOnly) return mark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
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
            color: AppColors.textSecondaryOf(context),
            fontFamily: 'Inter',
            letterSpacing: .3,
          ),
        ),
      );
}
