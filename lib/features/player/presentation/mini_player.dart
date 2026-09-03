import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../shared/widgets/album_art_thumb.dart';
import 'audio_player_screen.dart';

final miniPlayerItemProvider = StateProvider<MediaItem?>((_) => null);

final _miniIsPlayingProvider = Provider<bool>((ref) {
  return ref.watch(audioPlayerProvider.select((s) => s.isPlaying));
});

final _miniPositionProvider = Provider<Duration>((ref) {
  return ref.watch(audioPlayerProvider.select((s) => s.position));
});

final _miniDurationProvider = Provider<Duration>((ref) {
  return ref.watch(audioPlayerProvider.select((s) => s.duration));
});

/// Persistent Now Playing surface used across the app.
///
/// Design rule: media artwork is the visual focus; OTYA blue is reserved for
/// playback state/progress. The surface uses restrained glass treatment so it
/// remains visually connected to the content behind it without hurting text or
/// control contrast.
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  MediaItem? _lastItem;
  double _dragOffset = 0;

  static const _dismissThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _openPlayer(MediaItem item) {
    HapticFeedback.selectionClick();
    context.push('/player/audio', extra: {'item': item, 'resumeOnly': true});
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    ref.read(audioPlayerProvider.notifier).pause();
    ref.read(miniPlayerItemProvider.notifier).state = null;
    setState(() => _dragOffset = 0);
  }

  void _skipNext() {
    HapticFeedback.selectionClick();
    ref.read(audioPlayerProvider.notifier).skipNext();
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(miniPlayerItemProvider);

    if (item != null && _lastItem == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _slideCtrl.forward();
      });
    } else if (item == null && _lastItem != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _slideCtrl.reverse();
      });
    }
    _lastItem = item;

    if (item == null && !_slideCtrl.isAnimating) {
      return const SizedBox.shrink();
    }

    final displayItem = item ?? _lastItem;
    if (displayItem == null) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SlideTransition(
      position: _slideAnim,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy <= 0) return;
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dy)
                .clamp(0, _dismissThreshold * 1.5);
          });
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset >= _dismissThreshold ||
              (details.primaryVelocity ?? 0) > 400) {
            _dismiss();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 300) return;
          HapticFeedback.mediumImpact();
          if (velocity < 0) {
            ref.read(audioPlayerProvider.notifier).skipNext();
          } else {
            ref.read(audioPlayerProvider.notifier).skipPrevious();
          }
        },
        onTap: () => _openPlayer(displayItem),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, _dragOffset, 0),
          margin: EdgeInsets.fromLTRB(12, 0, 12, 8 + bottomInset),
          child: Opacity(
            opacity: (1 - _dragOffset / (_dismissThreshold * 1.5))
                .clamp(0.0, 1.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.07),
                        blurRadius: 26,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 70,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: AlbumArtThumb(
                                  albumArtPath: displayItem.albumArtPath,
                                  size: 54,
                                  borderRadius: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 7),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayItem.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayItem.artist ?? 'Unknown artist',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next',
                              visualDensity: VisualDensity.compact,
                              onPressed: _skipNext,
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: AppColors.textSecondary,
                                size: 23,
                              ),
                            ),
                            const _PlayPauseButton(),
                            const SizedBox(width: 5),
                          ],
                        ),
                      ),
                      const _MiniSeekBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(_miniIsPlayingProvider);

    return Semantics(
      button: true,
      label: isPlaying ? 'Pause' : 'Play',
      child: InkResponse(
        radius: 25,
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(audioPlayerProvider.notifier).togglePlay();
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.20),
                blurRadius: 15,
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _MiniSeekBar extends ConsumerStatefulWidget {
  const _MiniSeekBar();

  @override
  ConsumerState<_MiniSeekBar> createState() => _MiniSeekBarState();
}

class _MiniSeekBarState extends ConsumerState<_MiniSeekBar> {
  bool _isDragging = false;
  double _dragProgress = 0;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(_miniPositionProvider);
    final duration = ref.watch(_miniDurationProvider);
    final totalMs = duration.inMilliseconds;

    final progress = _isDragging
        ? _dragProgress
        : totalMs > 0
            ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;

    void updateFromDx(double dx, double width) {
      if (totalMs <= 0 || width <= 0) return;
      final fraction = (dx / width).clamp(0.0, 1.0);
      setState(() => _dragProgress = fraction);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (totalMs <= 0) return;
            final fraction =
                (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            ref.read(audioPlayerProvider.notifier).seek(
                  Duration(milliseconds: (fraction * totalMs).round()),
                );
          },
          onHorizontalDragStart: (details) {
            HapticFeedback.selectionClick();
            setState(() {
              _isDragging = true;
              _dragProgress = progress;
            });
            updateFromDx(details.localPosition.dx, constraints.maxWidth);
          },
          onHorizontalDragUpdate: (details) {
            updateFromDx(details.localPosition.dx, constraints.maxWidth);
          },
          onHorizontalDragEnd: (_) {
            if (totalMs > 0) {
              ref.read(audioPlayerProvider.notifier).seek(
                    Duration(milliseconds: (_dragProgress * totalMs).round()),
                  );
            }
            setState(() => _isDragging = false);
          },
          child: SizedBox(
            height: 10,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: _isDragging ? 4 : 3,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: _isDragging ? 4 : 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
