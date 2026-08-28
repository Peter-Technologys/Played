import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../../../shared/widgets/album_art_thumb.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';

class OtyaHomeScreen extends ConsumerWidget {
  const OtyaHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(mediaLibraryProvider);
    return WallpaperScaffold(
      body: SafeArea(
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: '$error',
            onRetry: () => ref.read(mediaLibraryProvider.notifier).refresh(),
          ),
          data: (items) => RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () => ref.read(mediaLibraryProvider.notifier).refresh(),
            child: _HomeBody(items: items),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final List<MediaItem> items;
  const _HomeBody({required this.items});

  @override
  Widget build(BuildContext context) {
    final recent = [...items]
      ..sort((a, b) => (b.lastPlayedAt ?? b.addedAt)
          .compareTo(a.lastPlayedAt ?? a.addedAt));
    final songs = recent.where((e) => !e.isVideo).take(12).toList();
    final videos = recent.where((e) => e.isVideo).take(8).toList();
    final latest = recent.take(10).toList();
    final musicCount = items.where((e) => !e.isVideo).length;
    final videoCount = items.where((e) => e.isVideo).length;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _TopBar(items: items)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
            child: Text(
              items.isEmpty
                  ? 'Your library is empty. Pull down to scan again.'
                  : '$musicCount songs · $videoCount videos',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .58),
                  ),
            ),
          ),
        ),
        if (latest.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Recently played'),
          ),
          SliverToBoxAdapter(child: _RecentRail(items: latest)),
        ],
        const SliverToBoxAdapter(
          child: _SectionTitle(title: 'Library shortcuts'),
        ),
        const SliverToBoxAdapter(child: _QuickGrid()),
        if (songs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Music',
              action: 'View all',
              onAction: () => context.go('/music'),
            ),
          ),
          SliverList.builder(
            itemCount: songs.take(5).length,
            itemBuilder: (context, index) => _MediaRow(item: songs[index]),
          ),
        ],
        if (videos.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Video',
              action: 'View all',
              onAction: () => context.go('/library'),
            ),
          ),
          SliverToBoxAdapter(child: _VideoRail(items: videos)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final List<MediaItem> items;
  const _TopBar({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'OTYA',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Search library',
            onPressed: () => showSearch<MediaItem?>(
              context: context,
              delegate: _OtyaSearch(items),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.25,
                    ),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Text(action!, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
}

class _RecentRail extends StatelessWidget {
  final List<MediaItem> items;
  const _RecentRail({required this.items});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 142,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 11),
          itemBuilder: (context, index) => _RecentCard(item: items[index]),
        ),
      );
}

class _RecentCard extends StatelessWidget {
  final MediaItem item;
  const _RecentCard({required this.item});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _open(context, item),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Art(item: item, size: 102, radius: 12),
              const SizedBox(height: 7),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                item.isVideo ? 'Video' : (item.artist ?? 'Music'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .52),
                ),
              ),
            ],
          ),
        ),
      );
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context) {
    final cards = [
      (Icons.queue_music_rounded, 'Playlists', '/playlists'),
      (Icons.folder_outlined, 'Folders', '/tools/folders'),
      (Icons.history_rounded, 'History', '/history'),
      (Icons.download_outlined, 'Downloads', '/downloads'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return InkWell(
            onTap: () => context.push(card.$3),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  Icon(card.$1, size: 20, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      card.$2,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _MediaRow extends StatelessWidget {
  final MediaItem item;
  const _MediaRow({required this.item});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 1),
        leading: _Art(item: item, size: 46, radius: 10),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          item.artist ?? item.album ?? item.formattedDuration,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.more_horiz_rounded, size: 20),
        onTap: () => _open(context, item),
      );
}

class _VideoRail extends StatelessWidget {
  final List<MediaItem> items;
  const _VideoRail({required this.items});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 164,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 11),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: () => _open(context, item),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 188,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Art(item: item, size: 188, height: 106, radius: 12),
                    const SizedBox(height: 7),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.formattedDuration,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .52),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _Art extends StatelessWidget {
  final MediaItem item;
  final double size;
  final double? height;
  final double radius;
  const _Art({required this.item, required this.size, this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (!item.isVideo) {
      return AlbumArtThumb(
        albumArtPath: item.albumArtPath,
        size: height ?? size,
        borderRadius: radius,
      );
    }
    final path = item.thumbnailPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: height ?? size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null && path.isNotEmpty)
              Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _videoPlaceholder(context),
              )
            else
              _videoPlaceholder(context),
            Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: .50),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoPlaceholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        child: Icon(
          Icons.movie_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .38),
          size: 30,
        ),
      );
}

class _OtyaSearch extends SearchDelegate<MediaItem?> {
  final List<MediaItem> all;
  _OtyaSearch(this.all) : super(searchFieldLabel: 'Search music and video');

  List<MediaItem> get _results {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all.take(30).toList();
    return all.where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.fileName.toLowerCase().contains(q) ||
          (item.artist?.toLowerCase().contains(q) ?? false) ||
          (item.album?.toLowerCase().contains(q) ?? false);
    }).take(100).toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            onPressed: () => query = '',
            icon: const Icon(Icons.close_rounded),
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded),
      );

  @override
  Widget buildResults(BuildContext context) => _view(context);

  @override
  Widget buildSuggestions(BuildContext context) => _view(context);

  Widget _view(BuildContext context) {
    final rows = _results;
    if (rows.isEmpty) return const Center(child: Text('No media found'));
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final item = rows[index];
        return ListTile(
          leading: _Art(item: item, size: 44, radius: 10),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.isVideo
                ? 'Video · ${item.formattedDuration}'
                : (item.artist ?? 'Music'),
          ),
          onTap: () {
            close(context, item);
            _open(context, item);
          },
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

void _open(BuildContext context, MediaItem item) {
  context.push(item.isVideo ? '/player/video' : '/player/audio', extra: item);
}
