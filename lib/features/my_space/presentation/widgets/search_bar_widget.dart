import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../playlists/playlist_screen.dart' show playlistsProvider;

/// Full-screen unified search delegate — songs, videos, playlists, folders.
/// Results are categorized and debounced at 300 ms.
class MediaSearchDelegate extends SearchDelegate<MediaItem?> {
  final List<MediaItem> allItems;
  final WidgetRef ref;

  MediaSearchDelegate({required this.allItems, required this.ref});

  @override
  String get searchFieldLabel => 'Search songs, videos, playlists...';

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
        hintStyle: TextStyle(color: AppColors.textSecondary),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
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
  Widget buildResults(BuildContext context) => _DebouncedResults(
        query: query,
        allItems: allItems,
        ref: ref,
        onSelect: (item) {
          close(context, item);
          context.push(
            item.isVideo ? '/player/video' : '/player/audio',
            extra: item,
          );
        },
      );

  @override
  Widget buildSuggestions(BuildContext context) => _DebouncedResults(
        query: query,
        allItems: allItems,
        ref: ref,
        onSelect: (item) {
          close(context, item);
          context.push(
            item.isVideo ? '/player/video' : '/player/audio',
            extra: item,
          );
        },
      );
}

class _DebouncedResults extends ConsumerStatefulWidget {
  final String query;
  final List<MediaItem> allItems;
  final WidgetRef ref;
  final ValueChanged<MediaItem> onSelect;

  const _DebouncedResults({
    required this.query,
    required this.allItems,
    required this.ref,
    required this.onSelect,
  });

  @override
  ConsumerState<_DebouncedResults> createState() => _DebouncedResultsState();
}

class _DebouncedResultsState extends ConsumerState<_DebouncedResults> {
  Timer? _debounce;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _schedule(widget.query);
  }

  @override
  void didUpdateWidget(_DebouncedResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _schedule(widget.query);
  }

  void _schedule(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _activeQuery = q);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _activeQuery.toLowerCase().trim();

    if (q.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 48),
            SizedBox(height: 12),
            Text('Search songs, videos, playlists, folders',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final songs = widget.allItems
        .where((e) =>
            !e.isVideo &&
            (_matches(e.title, q) ||
                _matches(e.artist ?? '', q) ||
                _matches(e.album ?? '', q)))
        .toList();

    final videos = widget.allItems
        .where((e) =>
            e.isVideo &&
            (_matches(e.title, q) || _matches(e.fileName, q)))
        .toList();

    // Folders
    final folderMap = <String, int>{};
    for (final item in widget.allItems) {
      final parts = item.filePath.split('/');
      if (parts.length > 1) {
        final folder = parts[parts.length - 2];
        if (_matches(folder, q)) {
          folderMap[folder] = (folderMap[folder] ?? 0) + 1;
        }
      }
    }

    // Playlists — safe read via ConsumerState
    List<dynamic> playlists = [];
    try {
      playlists = ref
          .read(playlistsProvider)
          .where((pl) => _matches(pl.name, q))
          .toList();
    } catch (_) {}

    final totalResults =
        songs.length + videos.length + folderMap.length + playlists.length;

    if (totalResults == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text('No results for "${widget.query}"',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (songs.isNotEmpty) ..._section(
            'Songs',
            Icons.music_note_rounded,
            AppColors.accentViolet,
            songs.map((item) => _MediaTile(
                  item: item,
                  onTap: () => widget.onSelect(item),
                )).toList(),
          ),
          if (videos.isNotEmpty) ..._section(
            'Videos',
            Icons.videocam_rounded,
            AppColors.accent,
            videos.map((item) => _MediaTile(
                  item: item,
                  onTap: () => widget.onSelect(item),
                )).toList(),
          ),
          if (playlists.isNotEmpty) ..._section(
            'Playlists',
            Icons.queue_music_rounded,
            AppColors.accent,
            playlists.map((pl) => _ResultTile(
                  icon: Icons.queue_music_rounded,
                  color: AppColors.accent,
                  title: pl.name as String,
                  subtitle:
                      '${(pl.mediaIds as List).length} track${(pl.mediaIds as List).length == 1 ? '' : 's'}',
                  onTap: () => context.push('/playlists'),
                )).toList(),
          ),
          if (folderMap.isNotEmpty) ..._section(
            'Folders',
            Icons.folder_rounded,
            AppColors.accent,
            folderMap.entries.map((e) => _ResultTile(
                  icon: Icons.folder_rounded,
                  color: AppColors.accent,
                  title: e.key,
                  subtitle: '${e.value} file${e.value == 1 ? '' : 's'}',
                  onTap: () {},
                )).toList(),
          ),
        ],
      ),
    );
  }

  bool _matches(String text, String q) => text.toLowerCase().contains(q);

  List<Widget> _section(
      String title, IconData icon, Color color, List<Widget> children) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      ...children,
    ];
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _MediaTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ResultTile(
      icon: item.isVideo
          ? Icons.videocam_rounded
          : Icons.music_note_rounded,
      color: item.isVideo ? AppColors.accent : AppColors.accentViolet,
      title: item.title,
      subtitle:
          '${item.artist ?? 'Unknown'} · ${DurationFormatter.format(item.duration)}',
      onTap: onTap,
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ResultTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
