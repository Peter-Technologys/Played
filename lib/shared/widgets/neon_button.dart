import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Reusable OTYA action button.
///
/// Kept under the legacy NeonButton name for API compatibility, but the visual
/// treatment now follows the approved restrained charcoal + purple system.
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
    final foreground = outlined ? activeColor : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: outlined
                ? Colors.transparent
                : enabled
                    ? activeColor
                    : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: outlined
                  ? activeColor.withValues(alpha: 0.8)
                  : enabled
                      ? activeColor.withValues(alpha: 0.55)
                      : AppColors.border,
            ),
            boxShadow: enabled && !outlined
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: enabled ? foreground : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled ? foreground : AppColors.textMuted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
