import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../features/settings/settings_provider.dart';
import '../../../shared/widgets/album_art_thumb.dart';
import 'audio_player_screen.dart';

// ── Provider ────────────────────────────────────────────────────────

final miniPlayerItemProvider = StateProvider<MediaItem?>((_) => null);

// ── TASK 3: Audio output route provider ────────────────────────────
// Detects the current audio output device name using audio_session.
// Returns null when detection fails so the label is hidden entirely.

final _audioOutputLabelProvider = FutureProvider<String?>((ref) async {
  try {
    final session = await AudioSession.instance;
    final devices = await session.getDevices(includeInputs: false);
    if (devices.isEmpty) return null;
    // Prefer the first active output device.
    final active = devices.firstWhere(
      (d) => d.isOutput,
      orElse: () => devices.first,
    );
    return active.name.isNotEmpty ? active.name : null;
  } catch (_) {
    return null;
  }
});

// ── TASK 2: Granular selectors — each rebuilds only its own subtree ─

/// Watches only [isPlaying] — rebuilds on play/pause toggle only.
final _miniIsPlayingProvider = Provider<bool>((ref) {
  return ref.watch(audioPlayerProvider.select((s) => s.isPlaying));
});

/// Watches only [position] — rebuilds on every position tick.
final _miniPositionProvider = Provider<Duration>((ref) {
  return ref.watch(audioPlayerProvider.select((s) => s.position));
});

/// Watches only [duration] — rebuilds when duration changes (once per track).
final _miniDurationProvider = Provider<Duration>((ref) {
  return ref.watch(audioPlayerProvider.select((s) => s.duration));
});

// ── Mini Player Widget ──────────────────────────────────────────────

/// Persistent collapsible mini player shown across all tabs.
/// Tap to expand to full audio player screen.
/// Swipe down to dismiss.
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

  // Swipe-to-dismiss tracking
  double _dragOffset = 0;
  static const _dismissThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    ref.read(miniPlayerItemProvider.notifier).state = null;
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(miniPlayerItemProvider);

    if (item != null && _lastItem == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) _slideCtrl.forward(); });
    } else if (item == null && _lastItem != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) _slideCtrl.reverse(); });
    }
    _lastItem = item;

    if (item == null && !_slideCtrl.isAnimating) {
      return const SizedBox.shrink();
    }

    final displayItem = item ?? _lastItem;
    if (displayItem == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnim,
      child: GestureDetector(
        // Swipe down to dismiss
        onVerticalDragUpdate: (d) {
          if (d.delta.dy > 0) {
            setState(() => _dragOffset =
                (_dragOffset + d.delta.dy).clamp(0, _dismissThreshold * 1.5));
          }
        },
        onVerticalDragEnd: (d) {
          if (_dragOffset >= _dismissThreshold ||
              (d.primaryVelocity ?? 0) > 400) {
            _dismiss();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/player/audio', extra: displayItem);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, _dragOffset, 0),
          child: Opacity(
            opacity: (1 - _dragOffset / (_dismissThreshold * 2)).clamp(0.3, 1.0),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border(
                  top: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Main content row ──────────────────────────────
                  SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        // Album art — resolves albumid: via MethodChannel
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(24)),
                          child: AlbumArtThumb(
                            albumArtPath: displayItem.albumArtPath,
                            size: 68,
                            borderRadius: 0,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Track info
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayItem.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayItem.artist ?? 'Unknown Artist',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // TASK 3: Dynamic audio output label.
                              // Hidden when detection fails.
                              const _AudioOutputLabel(),
                            ],
                          ),
                        ),

                        // Queue button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/player/audio', extra: displayItem);
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.queue_music_rounded,
                                color: AppColors.textSecondary, size: 18),
                          ),
                        ),

                        // TASK 2: Progress ring + play/pause — isolated widget
                        const _PlayPauseRing(),

                        // Close
                        GestureDetector(
                          onTap: _dismiss,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.close_rounded,
                                color: AppColors.textSecondary, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TASK 5: Draggable seek bar
                  const _MiniSeekBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── TASK 3: Audio output label widget ──────────────────────────────

class _AudioOutputLabel extends ConsumerWidget {
  const _AudioOutputLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelAsync = ref.watch(_audioOutputLabelProvider);
    return labelAsync.when(
      data: (label) {
        if (label == null) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_up_rounded,
                size: 10, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── TASK 2: Play/pause ring — only rebuilds on isPlaying / position / duration ──

class _PlayPauseRing extends ConsumerWidget {
  const _PlayPauseRing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(_miniIsPlayingProvider);
    final position  = ref.watch(_miniPositionProvider);
    final duration  = ref.watch(_miniDurationProvider);

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(audioPlayerProvider.notifier).togglePlay();
              },
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TASK 5: Draggable seek bar ──────────────────────────────────────

class _MiniSeekBar extends ConsumerStatefulWidget {
  const _MiniSeekBar();

  @override
  ConsumerState<_MiniSeekBar> createState() => _MiniSeekBarState();
}

class _MiniSeekBarState extends ConsumerState<_MiniSeekBar> {
  bool _isDragging = false;
  double _dragProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(_miniPositionProvider);
    final duration = ref.watch(_miniDurationProvider);
    final totalMs  = duration.inMilliseconds;

    final progress = _isDragging
        ? _dragProgress
        : (totalMs > 0
            ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0);

    return GestureDetector(
      // Tap to seek
      onTapDown: (details) {
        HapticFeedback.selectionClick();
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || totalMs <= 0) return;
        final fraction =
            (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        ref.read(audioPlayerProvider.notifier)
            .seek(Duration(milliseconds: (fraction * totalMs).toInt()));
      },
      // TASK 5: Drag to seek
      onHorizontalDragStart: (_) {
        HapticFeedback.lightImpact();
        setState(() {
          _isDragging = true;
          _dragProgress = progress;
        });
      },
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final fraction =
            (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
        setState(() => _dragProgress = fraction);
      },
      onHorizontalDragEnd: (_) {
        if (totalMs > 0) {
          ref.read(audioPlayerProvider.notifier).seek(
              Duration(milliseconds: (_dragProgress * totalMs).toInt()));
        }
        setState(() => _isDragging = false);
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: _isDragging ? 4.0 : 2.5,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ),
    );
  }
}
