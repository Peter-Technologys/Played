import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/app_dimensions.dart';

/// Shared Otya empty-state presentation.
///
/// Empty states should feel calm and intentional rather than like decorative
/// loading screens. The component follows the active Material 3 theme, keeps
/// copy readable at larger text scales and respects the platform reduced-motion
/// preference.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = accentColor ?? scheme.primary;

    Widget illustration = ExcludeSemantics(
      child: SizedBox.square(
        dimension: 104,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .07),
          ),
          child: Center(
            child: SizedBox.square(
              dimension: 68,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .12),
                  border: Border.all(
                    color: color.withValues(alpha: .18),
                  ),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
            ),
          ),
        ),
      ),
    );

    if (!reduceMotion) {
      illustration = illustration
          .animate()
          .fadeIn(duration: AppDimensions.motionStandard)
          .scaleXY(
            begin: .96,
            end: 1,
            duration: AppDimensions.motionEmphasized,
            curve: Curves.easeOutCubic,
          );
    }

    Widget copy = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (!reduceMotion) {
      copy = copy.animate().fadeIn(
            duration: AppDimensions.motionStandard,
            delay: const Duration(milliseconds: 70),
          );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space32,
          vertical: AppDimensions.space24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Semantics(
            container: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                illustration,
                const SizedBox(height: AppDimensions.space24),
                copy,
                if (action != null) ...[
                  const SizedBox(height: AppDimensions.space24),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
