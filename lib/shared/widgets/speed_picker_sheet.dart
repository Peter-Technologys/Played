// lib/shared/widgets/speed_picker_sheet.dart
//
// Shared bottom-sheet speed picker used by both the audio and video players.
// Extracted to eliminate the duplicate speed-picker implementations that
// previously existed in audio_player_screen.dart and video_player_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';

/// Shows a bottom sheet that lets the user pick a playback speed.
///
/// [currentSpeed] — the currently active speed (highlighted in the grid).
/// [onSpeedSelected] — called with the chosen speed when the user taps a chip.
/// [speeds] — optional list of speed values; defaults to [0.5, 1.0, 1.25, 1.5, 2.0].
Future<void> showSpeedPickerSheet({
  required BuildContext context,
  required double currentSpeed,
  required ValueChanged<double> onSpeedSelected,
  List<double> speeds = const [0.5, 1.0, 1.25, 1.5, 2.0],
}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
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

/// The content widget for the speed picker bottom sheet.
class SpeedPickerSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;
  final List<double> speeds;

  const SpeedPickerSheet({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
    this.speeds = const [0.5, 1.0, 1.25, 1.5, 2.0],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Playback Speed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: speeds.map((s) {
              final isActive = currentSpeed == s;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                  onSpeedSelected(s);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentViolet],
                          )
                        : null,
                    color: isActive ? null : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? Colors.transparent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.black : AppColors.textPrimary,
                      fontFamily: 'Inter',
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
