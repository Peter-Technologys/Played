import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import 'audio_player_screen.dart';

// ── Provider ────────────────────────────────────────────────────────

final miniPlayerItemProvider = StateProvider<MediaItem?>((_) => null);

// ── Mini Player Widget ──────────────────────────────────────────────

/// Persistent collapsible mini player shown across all tabs.
/// Tap to expand to full audio player screen.
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

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(miniPlayerItemProvider);
    final playerState = ref.watch(audioPlayerProvider);

    // Animate in when a new item appears, animate out when null
    if (item != null && _lastItem == null) {
      _slideCtrl.forward();
    } else if (item == null && _lastItem != null) {
      _slideCtrl.reverse();
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
        onTap: () => context.push('/player/audio', extra: displayItem),
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Album art
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accentViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(18)),
                ),
                child: const Icon(Icons.music_note_rounded,
                    color: Colors.black, size: 28),
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(miniPlayerItemProvider.notifier).state = null;
                },
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
    );
  }
}
