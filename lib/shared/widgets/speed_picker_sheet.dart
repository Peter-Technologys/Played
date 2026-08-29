// lib/shared/widgets/speed_picker_sheet.dart
//
// Shared bottom-sheet speed picker used by both the audio and video players.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';

/// Shows a bottom sheet that lets the user pick a playback speed.
Future<void> showSpeedPickerSheet({
  required BuildContext context,
  required double currentSpeed,
  required ValueChanged<double> onSpeedSelected,
  List<double> speeds = const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: scheme.surface.withValues(alpha: 0.96),
    barrierColor: Colors.black.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SpeedPickerSheet(
      currentSpeed: currentSpeed,
      onSpeedSelected: onSpeedSelected,
      speeds: speeds,
    ),
  );
}

/// Content shared by audio and video playback.
class SpeedPickerSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;
  final List<double> speeds;

  const SpeedPickerSheet({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
    this.speeds = const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Playback Speed',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how fast your media plays',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.68),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: speeds.map((speed) {
              final isActive = (currentSpeed - speed).abs() < 0.001;
              return Semantics(
                button: true,
                selected: isActive,
                label: '$speed times playback speed',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                    onSpeedSelected(speed);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [
                                AppColors.accent,
                                AppColors.accentViolet,
                              ],
                            )
                          : null,
                      color: isActive
                          ? null
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.72,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? Colors.transparent
                            : scheme.outline.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.black : scheme.onSurface,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
