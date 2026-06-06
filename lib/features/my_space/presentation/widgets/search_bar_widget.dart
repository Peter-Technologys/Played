import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/utils/duration_formatter.dart';
import 'media_card.dart';

/// Full-screen search delegate for media files.
class MediaSearchDelegate extends SearchDelegate<MediaItem?> {
  final List<MediaItem> allItems;

  MediaSearchDelegate({required this.allItems});

  @override
  String get searchFieldLabel => 'Search songs, videos...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
            color: AppColors.textSecondary, fontFamily: 'SpaceGrotesk'),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'SpaceGrotesk',
            fontSize: 16),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear_rounded,
                color: AppColors.textSecondary),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded,
            color: AppColors.textPrimary),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase().trim();
    final results = q.isEmpty
        ? allItems
        : allItems
            .where((item) =>
                item.title.toLowerCase().contains(q) ||
                (item.artist?.toLowerCase().contains(q) ?? false) ||
                item.fileName.toLowerCase().contains(q))
            .toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text('No results for "$query"',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'SpaceGrotesk')),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = results[i];
          return GestureDetector(
            onTap: () {
              close(context, item);
              final route =
                  item.isVideo ? '/player/video' : '/player/audio';
              context.push(route, extra: item);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.isVideo
                          ? Icons.play_circle_outline_rounded
                          : Icons.music_note_rounded,
                      color: item.isVideo
                          ? AppColors.accent
                          : AppColors.accentViolet,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontFamily: 'SpaceGrotesk',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${item.artist ?? 'Unknown'} · ${DurationFormatter.format(item.duration)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    item.isVideo
                        ? Icons.videocam_rounded
                        : Icons.headphones_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
