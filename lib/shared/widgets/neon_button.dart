import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/theme/app_colors.dart';

/// Reusable neon gradient button used across all screens.
class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool outlined;
  final double height;
  final Color? color;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.enabled = true,
    this.outlined = false,
    this.height = 56,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.accent;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: enabled && !outlined
              ? LinearGradient(
                  colors: [activeColor, AppColors.accentViolet],
                )
              : null,
          color: outlined
              ? Colors.transparent
              : enabled
                  ? null
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: outlined
              ? Border.all(color: activeColor, width: 1.5)
              : enabled
                  ? null
                  : Border.all(color: AppColors.border),
          boxShadow: enabled && !outlined
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...
              [
                Icon(
                  icon,
                  color: outlined
                      ? activeColor
                      : enabled
                          ? Colors.black
                          : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
              ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: outlined
                    ? activeColor
                    : enabled
                        ? Colors.black
                        : AppColors.textSecondary,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
