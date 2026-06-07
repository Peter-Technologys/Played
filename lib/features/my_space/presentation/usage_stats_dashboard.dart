import 'package:flutter/material.dart';
// flutter/services.dart removed — all used elements are provided by flutter/material.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/media_item.dart';

// ── Stats Provider ─────────────────────────────────────────────

class UsageStats {
  final Duration totalListeningTime;
  final MediaItem? mostPlayed;
  final int totalTracksPlayed;
  final String topFeature;
  const UsageStats({
    required this.totalListeningTime,
    this.mostPlayed,
    required this.totalTracksPlayed,
    required this.topFeature,
  });
}

final usageStatsProvider = FutureProvider<UsageStats>((ref) async {
  final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 100);
  final total = history.fold<Duration>(
    Duration.zero,
    (sum, item) => sum + (item.duration ?? Duration.zero),
  );
  final mostPlayed = history.isNotEmpty ? history.first : null;
  return UsageStats(
    totalListeningTime: total,
    mostPlayed: mostPlayed,
    totalTracksPlayed: history.length,
    topFeature: 'My Space',
  );
});

// ── Stats Dashboard Widget ───────────────────────────────────────

class UsageStatsDashboard extends ConsumerWidget {
  const UsageStatsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(usageStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.08),
              AppColors.accentViolet.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                const Text('YOUR WEEK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 1.2,
                      fontFamily: 'SpaceGrotesk',
                    )),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatCard(
                  icon: Icons.headphones_rounded,
                  label: 'Listening Time',
                  value: _fmtDuration(stats.totalListeningTime),
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.music_note_rounded,
                  label: 'Tracks Played',
                  value: '${stats.totalTracksPlayed}',
                  color: AppColors.accentViolet,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.star_rounded,
                  label: 'Top Feature',
                  value: stats.topFeature,
                  color: Colors.amber,
                ),
              ],
            ),
            if (stats.mostPlayed != null) ...
              [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.repeat_rounded,
                        color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 6),
                    const Text('Most played: ',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    Expanded(
                      child: Text(
                        stats.mostPlayed!.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
    );
  }

  static String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'SpaceGrotesk',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
