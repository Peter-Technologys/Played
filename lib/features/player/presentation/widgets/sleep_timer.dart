import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/services/playback_coordinator.dart';

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>(
  (_) => SleepTimerNotifier(),
);

class SleepTimerState {
  const SleepTimerState({this.remaining, this.isActive = false});

  final Duration? remaining;
  final bool isActive;
}

/// One owner for the user-selected countdown.
///
/// A sleep timer is a fixed deadline, not an inactivity detector. The final
/// 30 seconds fade the active OTYA player's own volume and restore the previous
/// volume when cancelled or after the expiry callback pauses playback.
class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  SleepTimerNotifier() : super(const SleepTimerState());

  Timer? _ticker;
  DateTime? _deadline;
  double? _volumeBeforeFade;

  void start(Duration duration, VoidCallback onExpire) {
    cancel(restoreVolume: true);
    if (duration <= Duration.zero) return;

    _deadline = DateTime.now().add(duration);
    state = SleepTimerState(remaining: duration, isActive: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick(onExpire);
    });
  }

  void _tick(VoidCallback onExpire) {
    final deadline = _deadline;
    if (deadline == null || !state.isActive) {
      _ticker?.cancel();
      return;
    }

    final now = DateTime.now();
    final remaining = deadline.difference(now);
    if (remaining <= Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      _deadline = null;
      state = const SleepTimerState(isActive: false);
      _restoreVolume();
      onExpire();
      return;
    }

    state = SleepTimerState(remaining: remaining, isActive: true);
    if (remaining <= const Duration(seconds: 30)) {
      _fadeVolume(remaining);
    }
  }

  void _fadeVolume(Duration remaining) {
    final player = PlaybackCoordinator.instance.activePlayer;
    if (player == null) return;

    _volumeBeforeFade ??= player.state.volume;
    final original = _volumeBeforeFade ?? 100.0;
    final fraction = (remaining.inMilliseconds / 30000).clamp(0.0, 1.0);
    unawaited(player.setVolume(original * fraction));
  }

  void _restoreVolume() {
    final original = _volumeBeforeFade;
    _volumeBeforeFade = null;
    if (original == null) return;
    final player = PlaybackCoordinator.instance.activePlayer;
    if (player != null) unawaited(player.setVolume(original));
  }

  void cancel({bool restoreVolume = true}) {
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
    if (restoreVolume) _restoreVolume();
    state = const SleepTimerState(isActive: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _restoreVolume();
    super.dispose();
  }
}

class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key, required this.onExpire});

  final VoidCallback onExpire;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: timer.isActive ? 'Cancel sleep timer' : 'Set sleep timer',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        onTap: () {
          HapticFeedback.lightImpact();
          if (timer.isActive) {
            ref.read(sleepTimerProvider.notifier).cancel();
          } else {
            _showPicker(context, ref);
          }
        },
        child: AnimatedContainer(
          duration: AppDimensions.motionStandard,
          constraints: const BoxConstraints(
            minHeight: AppDimensions.minimumTouchTarget,
            minWidth: AppDimensions.minimumTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: timer.isActive
                ? AppColors.accent.withValues(alpha: .13)
                : scheme.onSurface.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(
              color: timer.isActive
                  ? AppColors.accent.withValues(alpha: .42)
                  : scheme.outlineVariant.withValues(alpha: .62),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bedtime_rounded,
                color: timer.isActive
                    ? AppColors.accent
                    : scheme.onSurfaceVariant,
                size: 18,
              ),
              if (timer.isActive && timer.remaining != null) ...[
                const SizedBox(width: 6),
                Text(
                  _format(timer.remaining!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _format(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '$hours:$minutes';
    }
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    const options = <Duration>[
      Duration(minutes: 5),
      Duration(minutes: 10),
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(minutes: 45),
      Duration(hours: 1),
    ];

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .92),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sleep timer',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        fontFamily: 'Inter',
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'OTYA gently fades playback during the final 30 seconds, then pauses.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: options.map((duration) {
                        final label = duration.inHours >= 1
                            ? '${duration.inHours} hour'
                            : '${duration.inMinutes} min';
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            HapticFeedback.mediumImpact();
                            ref
                                .read(sleepTimerProvider.notifier)
                                .start(duration, onExpire);
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 46,
                              minWidth: 88,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: .54),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: .56),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 17,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
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
      },
    );
  }
}
