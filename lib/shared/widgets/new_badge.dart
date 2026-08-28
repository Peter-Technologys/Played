import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Small discovery marker for features or newly discovered local media.
/// Keep this visually quiet so badges never become the layout.
class OtyaNewBadge extends StatelessWidget {
  final String label;
  final EdgeInsets padding;

  const OtyaNewBadge({
    super.key,
    this.label = 'NEW',
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .35,
          height: 1.1,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
