import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/widgets/album_art_thumb.dart';
import 'audio_player_screen.dart';
import 'mini_player.dart';
import 'queue_screen.dart';

/// Distraction-reduced large playback controls.
///
/// This is an in-app accessibility/convenience surface, not an Android Auto
/// interface. System UI changes are lifecycle-owned and always restored when
/// the route exits, including Android back/system gestures.
class CarModeScreen extends ConsumerStatefulWidget {
  const CarModeScreen({super.key});

  @override
  ConsumerState<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends ConsumerState<CarModeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _close() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final item = ref.watch(miniPlayerItemProvider);
    final isShuffle = ref.watch(queueProvider.select((queue) => queue.shuffle));
    final progress = playerState.duration.inMilliseconds > 0
        ? (playerState.position.inMilliseconds /
                playerState.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final content = _PlaybackContent(
                title: item?.title ?? 'Nothing playing',
                artist: item?.artist != null && item!.artist != '<unknown>'
                    ? item.artist!
                    : 'Unknown artist',
                albumArtPath: item?.albumArtPath,
                progress: progress,
                isPlaying: playerState.isPlaying,
                isShuffle: isShuffle,
                repeat: playerState.repeat,
                onSeek: (value) {
                  final duration = playerState.duration.inMilliseconds;
                  ref.read(audioPlayerProvider.notifier).seek(
                        Duration(
                          milliseconds: (value * duration).round(),
                        ),
                      );
                },
                onPrevious: () =>
                    ref.read(audioPlayerProvider.notifier).skipPrevious(),
                onToggle: () =>
                    ref.read(audioPlayerProvider.notifier).togglePlay(),
                onNext: () =>
                    ref.read(audioPlayerProvider.notifier).skipNext(),
                onShuffle: () =>
                    ref.read(audioPlayerProvider.notifier).toggleShuffle(),
                onRepeat: () =>
                    ref.read(audioPlayerProvider.notifier).cycleRepeat(),
                onQueue: () => showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const QueueScreen(),
                ),
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Exit large controls',
                          onPressed: _close,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.touch_app_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'LARGE CONTROLS',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: wide
                        ? Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: content,
                            ),
                          )
                        : content,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlaybackContent extends StatelessWidget {
  const _PlaybackContent({
    required this.title,
    required this.artist,
    required this.albumArtPath,
    required this.progress,
    required this.isPlaying,
    required this.isShuffle,
    required this.repeat,
    required this.onSeek,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.onQueue,
  });

  final String title;
  final String artist;
  final String? albumArtPath;
  final double progress;
  final bool isPlaying;
  final bool isShuffle;
  final RepeatState repeat;
  final ValueChanged<double> onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 138,
            height: 138,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                if (isPlaying)
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: .10),
                    blurRadius: 30,
                    spreadRadius: -6,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppDimensions.radiusXLarge - 3,
              ),
              child: AlbumArtThumb(
                albumArtPath: albumArtPath,
                size: 132,
                borderRadius: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -.45,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            label: 'Playback position',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withValues(alpha: .14),
                trackHeight: 5,
              ),
              child: Slider(
                value: progress,
                onChanged: onSeek,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LargeControl(
                tooltip: 'Previous',
                icon: Icons.skip_previous_rounded,
                onPressed: onPrevious,
              ),
              const SizedBox(width: 22),
              _LargeControl(
                tooltip: isPlaying ? 'Pause' : 'Play',
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                primary: true,
                onPressed: onToggle,
              ),
              const SizedBox(width: 22),
              _LargeControl(
                tooltip: 'Next',
                icon: Icons.skip_next_rounded,
                onPressed: onNext,
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SecondaryControl(
                tooltip: 'Shuffle',
                icon: Icons.shuffle_rounded,
                active: isShuffle,
                onPressed: onShuffle,
              ),
              _SecondaryControl(
                tooltip: repeat == RepeatState.one
                    ? 'Repeat one'
                    : 'Repeat',
                icon: repeat == RepeatState.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                active: repeat != RepeatState.off,
                onPressed: onRepeat,
              ),
              _SecondaryControl(
                tooltip: 'Queue',
                icon: Icons.queue_music_rounded,
                active: false,
                onPressed: onQueue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LargeControl extends StatelessWidget {
  const _LargeControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: primary ? 88 : 72,
        child: IconButton.filled(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor:
                primary ? AppColors.accent : AppColors.surfaceElevated,
            foregroundColor: Colors.white,
            side: primary
                ? null
                : const BorderSide(color: AppColors.border),
          ),
          iconSize: primary ? 46 : 38,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _SecondaryControl extends StatelessWidget {
  const _SecondaryControl({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 64,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: active
                ? AppColors.accent.withValues(alpha: .16)
                : AppColors.surface,
            foregroundColor: active ? AppColors.accent : AppColors.textSecondary,
            side: BorderSide(
              color: active
                  ? AppColors.accent.withValues(alpha: .34)
                  : AppColors.border,
            ),
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}
