// lib/shared/widgets/speed_picker_sheet.dart
//
// Shared bottom-sheet speed picker used by both the audio and video players.

import 'dart:ui';

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
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.48),
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

  String _label(double speed) => speed == speed.truncateToDouble()
      ? '${speed.toInt()}x'
      : '${speed}x';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Playback speed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontFamily: 'Inter',
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Choose how fast your media plays.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 18),
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
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                          onSpeedSelected(speed);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          constraints: const BoxConstraints(
                            minWidth: 66,
                            minHeight: 46,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.accent
                                : scheme.surfaceContainerHighest.withValues(
                                    alpha: 0.54,
                                  ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.accent
                                  : scheme.outlineVariant.withValues(alpha: 0.56),
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.18),
                                      blurRadius: 16,
                                      spreadRadius: -4,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            _label(speed),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isActive ? Colors.white : scheme.onSurface,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
