import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../features/settings/settings_provider.dart';
import 'audio_player_screen.dart';

// ── Provider ────────────────────────────────────────────────────────

final miniPlayerItemProvider = StateProvider<MediaItem?>((_) => null);

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

  Widget _artFallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.accent, AppColors.accentViolet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 28),
  );

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(miniPlayerItemProvider);
    final playerState = ref.watch(audioPlayerProvider);

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
              height: 68,
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
              child: Row(
                children: [
                  // Album art — real art when available, gradient fallback
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24)),
                    child: SizedBox(
                      width: 68, height: 68,
                      child: displayItem.albumArtPath != null &&
                              !displayItem.albumArtPath!.startsWith('albumid:')
                          ? Image.file(
                              File(displayItem.albumArtPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _artFallback(),
                            )
                          : _artFallback(),
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
                      ],
                    ),
                  ),

                  // Crossfade indicator — shown when crossfade > 0
                  Builder(builder: (context) {
                    final settings = ref.watch(settingsProvider);
                    if (settings.crossfadeDuration <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: 'Crossfade ${settings.crossfadeDuration.toStringAsFixed(0)}s',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentViolet.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppColors.accentViolet
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz_rounded,
                                  color: AppColors.accentViolet, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                '${settings.crossfadeDuration.toStringAsFixed(0)}s',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentViolet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Progress ring + play/pause
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: playerState.duration.inMilliseconds > 0
                                ? (playerState.position.inMilliseconds /
                                        playerState.duration.inMilliseconds)
                                    .clamp(0.0, 1.0)
                                : 0,
                            strokeWidth: 2.5,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.accent),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(audioPlayerProvider.notifier)
                                  .togglePlay();
                            },
                            child: Icon(
                              playerState.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

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
          ),
        ),
      ),
    );
  }
}
