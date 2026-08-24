import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/otya_database.dart';
import '../../../../core/models/media_item.dart';
import '../providers/my_space_provider.dart';
import '../../../player/presentation/queue_screen.dart';

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guard: DB may not be initialized on very first frame
    List<MediaItem> favorites;
    try {
      final allItems = ref.watch(mediaLibraryProvider).valueOrNull ?? [];
      favorites = OtyaDatabase.instance.getFavoriteItems(allItems);
    } catch (_) {
      favorites = [];
    }

    if (favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded,
                color: AppColors.textSecondary, size: 64),
            SizedBox(height: 16),
            Text('No favorites yet',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Tap the heart in the audio player to add songs here.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: favorites.length,
      itemBuilder: (context, i) {
        final item = favorites[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.redAccent, size: 22),
          ),
          title: Text(item.title,
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary, fontFamily: 'Inter',
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.artist != null && item.artist != '<unknown>'
                ? item.artist!
                : item.formattedDuration,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.formattedDuration,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  try {
                    await OtyaDatabase.instance.setFavoriteFlag(item.id, false);
                    // Use read (not invalidate) to avoid provider disposal crash
                    ref.read(mediaLibraryProvider.notifier).refresh();
                  } catch (_) {}
                },
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.redAccent, size: 18),
              ),
            ],
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            ref
                .read(queueProvider.notifier)
                .setQueue(favorites, startIndex: i);
            context.push(
              item.isVideo ? '/player/video' : '/player/audio',
              extra: item,
            );
          },
        );
      },
    );
  }
}
