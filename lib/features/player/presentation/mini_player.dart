import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import 'audio_player_screen.dart';

// ── Provider ───────────────────────────────────────────────

final miniPlayerItemProvider = StateProvider<MediaItem?>((_) => null);

// ── Mini Player Widget ─────────────────────────────────────────

/// Persistent collapsible mini player shown across all tabs.
/// Tap to expand to full audio player screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(miniPlayerItemProvider);
    final playerState = ref.watch(audioPlayerProvider);

    if (item == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/player/audio', extra: item),
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
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18)),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: AppColors.accent, size: 28),
            ),

            const SizedBox(width: 12),

            // Track info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
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
                    item.artist ?? 'Unknown Artist',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Progress bar
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
                          ? playerState.position.inMilliseconds /
                              playerState.duration.inMilliseconds
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
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
