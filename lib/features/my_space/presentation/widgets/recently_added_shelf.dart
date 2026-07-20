import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/database/played_database.dart';
import '../providers/my_space_provider.dart';
import '../../player/presentation/queue_screen.dart';

/// Horizontal shelf showing files added in the last 7 days.
class RecentlyAddedShelf extends ConsumerWidget {
  const RecentlyAddedShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = ref.watch(mediaLibraryProvider).valueOrNull ?? [];
    final recent = PlayedDatabase.instance.getRecentlyAddedItems(allItems, days: 7);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              const Text('RECENTLY ADDED',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary, letterSpacing: 1.3,
                    fontFamily: 'Inter',
                  )),
              const Spacer(),
              Text('${recent.length} new',
                  style: const TextStyle(
                    fontSize: 10, color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = recent[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(queueProvider.notifier).setQueue(recent, startIndex: i);
                  context.push(
                    item.isVideo ? '/player/video' : '/player/audio',
                    extra: item,
                  );
                },
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.12),
                        AppColors.accentViolet.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: item.isVideo
                                  ? AppColors.accent.withValues(alpha: 0.15)
                                  : AppColors.accentViolet.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.music_note_rounded,
                              color: item.isVideo
                                  ? AppColors.accent
                                  : AppColors.accentViolet,
                              size: 16,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('NEW',
                                style: TextStyle(
                                  fontSize: 8, fontWeight: FontWeight.w800,
                                  color: AppColors.accent, letterSpacing: 0.5,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(item.title,
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary, fontFamily: 'Inter',
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(_daysAgo(item.addedAt),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _daysAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
