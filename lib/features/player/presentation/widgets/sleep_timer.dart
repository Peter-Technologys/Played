import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';

// ── Provider ───────────────────────────────────────────────

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
  (_) => SleepTimerNotifier(),
);

class SleepTimerState {
  final Duration? remaining;
  final bool isActive;
  const SleepTimerState({this.remaining, this.isActive = false});
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  SleepTimerNotifier() : super(const SleepTimerState());

  void start(Duration duration, VoidCallback onExpire) {
    state = SleepTimerState(remaining: duration, isActive: true);
    _tick(duration, onExpire);
  }

  Future<void> _tick(Duration remaining, VoidCallback onExpire) async {
    while (remaining.inSeconds > 0 && state.isActive) {
      await Future.delayed(const Duration(seconds: 1));
      if (!state.isActive) return;
      remaining -= const Duration(seconds: 1);
      state = SleepTimerState(remaining: remaining, isActive: true);
    }
    if (state.isActive) {
      state = const SleepTimerState(isActive: false);
      onExpire();
    }
  }

  void cancel() => state = const SleepTimerState(isActive: false);
}

// ── Sleep Timer Button ─────────────────────────────────────────

class SleepTimerButton extends ConsumerWidget {
  final VoidCallback onExpire;
  const SleepTimerButton({super.key, required this.onExpire});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (timer.isActive) {
          ref.read(sleepTimerProvider.notifier).cancel();
        } else {
          _showPicker(context, ref);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: timer.isActive
              ? AppColors.accentViolet.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: timer.isActive
                ? AppColors.accentViolet
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bedtime_rounded,
              color: timer.isActive
                  ? AppColors.accentViolet
                  : AppColors.textSecondary,
              size: 16,
            ),
            if (timer.isActive && timer.remaining != null) ...
              [
                const SizedBox(width: 5),
                Text(
                  _fmt(timer.remaining!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentViolet,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    final options = [
      const Duration(minutes: 5),
      const Duration(minutes: 10),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(hours: 1),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sleep Timer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'SpaceGrotesk',
                )),
            const SizedBox(height: 4),
            const Text('Audio fades out smoothly when timer ends.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((d) {
                final label = d.inHours >= 1
                    ? '${d.inHours}h'
                    : '${d.inMinutes}m';
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                    ref
                        .read(sleepTimerProvider.notifier)
                        .start(d, onExpire);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk',
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
