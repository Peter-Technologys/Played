import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';

class BatterySaverToggle extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool> onToggle;

  const BatterySaverToggle({
    super.key,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = isActive ? 'Turn battery saver off' : 'Turn battery saver on';

    return Semantics(
      button: true,
      toggled: isActive,
      label: 'Battery saver',
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(!isActive);
          },
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.accent : Colors.white24,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive
                        ? Icons.battery_saver_rounded
                        : Icons.battery_full_rounded,
                    color: isActive ? AppColors.accent : Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isActive ? 'Saver ON' : 'Saver',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.accent : Colors.white54,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate(target: isActive ? 1 : 0)
        .shimmer(
          duration: 1200.ms,
          color: AppColors.accent.withValues(alpha: 0.3),
        );
  }
}
