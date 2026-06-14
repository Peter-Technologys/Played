import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../player/presentation/audio_player_screen.dart';
import '../../player/presentation/mini_player.dart';
import '../../player/presentation/queue_screen.dart';

/// Full-screen car mode — large buttons, no distractions.
class CarModeScreen extends ConsumerWidget {
  const CarModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ps   = ref.watch(audioPlayerProvider);
    final item = ref.watch(miniPlayerItemProvider);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 22),
                    ),
                  ),
                  const Spacer(),
                  const Row(
                    children: [
                      Icon(Icons.directions_car_rounded,
                          color: AppColors.accent, size: 18),
                      SizedBox(width: 6),
                      Text('CAR MODE',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.accent, letterSpacing: 1.5,
                          )),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Album art placeholder
            Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.2),
                    AppColors.accentViolet.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 40, spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: AppColors.accent, size: 72),
            ),

            const SizedBox(height: 32),

            // Track info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    item?.title ?? 'Nothing playing',
                    style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: Colors.white, fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item?.artist != null && item!.artist != '<unknown>'
                        ? item.artist!
                        : 'Unknown Artist',
                    style: const TextStyle(fontSize: 16, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: ps.duration.inMilliseconds > 0
                      ? (ps.position.inMilliseconds / ps.duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: (v) => ref.read(audioPlayerProvider.notifier).seek(
                      Duration(milliseconds: (v * ps.duration.inMilliseconds).toInt())),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Large controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CarBtn(
                    icon: Icons.skip_previous_rounded, size: 56,
                    onTap: () => ref.read(audioPlayerProvider.notifier).skipPrevious(),
                  ),
                  _CarBtn(
                    icon: ps.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    size: 88, color: AppColors.accent,
                    onTap: () => ref.read(audioPlayerProvider.notifier).togglePlay(),
                  ),
                  _CarBtn(
                    icon: Icons.skip_next_rounded, size: 56,
                    onTap: () => ref.read(audioPlayerProvider.notifier).skipNext(),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom row
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CarSmallBtn(
                    icon: Icons.shuffle_rounded, active: ps.isShuffle,
                    onTap: () => ref.read(audioPlayerProvider.notifier).toggleShuffle(),
                  ),
                  _CarSmallBtn(
                    icon: ps.repeat == RepeatState.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    active: ps.repeat != RepeatState.off,
                    onTap: () => ref.read(audioPlayerProvider.notifier).cycleRepeat(),
                  ),
                  _CarSmallBtn(
                    icon: Icons.queue_music_rounded, active: false,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.surface,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24))),
                      builder: (_) => const QueueScreen(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;
  const _CarBtn({
    required this.icon, required this.size,
    required this.onTap, this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onTap, child: Icon(icon, color: color, size: size));
}

class _CarSmallBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _CarSmallBtn({required this.icon, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? AppColors.accent : Colors.white12),
        ),
        child: Icon(icon,
            color: active ? AppColors.accent : Colors.white54, size: 28),
      ),
    );
  }
}
