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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _TopBar(items: items)),
        SliverToBoxAdapter(child: _HeroCard(items: items)),
        if (latest.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Recently Played', action: 'See all'),
          ),
          SliverToBoxAdapter(child: _RecentRail(items: latest)),
        ],
        const SliverToBoxAdapter(
          child: _SectionTitle(title: 'Quick Access'),
        ),
        SliverToBoxAdapter(
          child: _QuickGrid(
            musicCount: items.where((e) => !e.isVideo).length,
            videoCount: items.where((e) => e.isVideo).length,
            downloadCount: items.where(_isDownloaded).length,
          ),
        ),
        if (songs.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Your Music', action: 'Library'),
          ),
          SliverList.builder(
            itemCount: songs.take(5).length,
            itemBuilder: (context, index) => _MediaRow(item: songs[index]),
          ),
        ],
        if (videos.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Recent Videos', action: 'Library'),
          ),
          SliverToBoxAdapter(child: _VideoRail(items: videos)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 130)),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14D9FF), Color(0xFF7B3CFF), Color(0xFFFF2CAA)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: .25),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OTYA',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                ),
                Text(
                  'Your sound · Your way',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55),
                      ),
                ),
              ],
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
            tooltip: 'OTYA AI',
            onPressed: () => context.go('/ai'),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final List<MediaItem> items;
  const _HeroCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final music = items.where((e) => !e.isVideo).length;
    final videos = items.where((e) => e.isVideo).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: .18),
            const Color(0xFFFF2CAA).withValues(alpha: .12),
            Theme.of(context).colorScheme.surface.withValues(alpha: .9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  items.isEmpty
                      ? 'Your media will appear here after scanning.'
                      : '$music songs · $videos videos ready to play',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .62),
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/ai'),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Ask OTYA'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF6C3BFF), Color(0xFFFF2BA6), Color(0xFFFF8A00), Color(0xFF00D9FF)],
              ),
              boxShadow: [
                BoxShadow(color: AppColors.accent.withValues(alpha: .28), blurRadius: 24),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0B0B14)),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (action != null)
              Text(action!,
                  style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _RecentRail extends StatelessWidget {
  final List<MediaItem> items;
  const _RecentRail({required this.items});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 145,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
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
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 105,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Art(item: item, size: 102, radius: 16),
              const SizedBox(height: 7),
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(item.isVideo ? 'Video' : (item.artist ?? 'Music'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55),
                  )),
            ],
          ),
        ),
      );
}

class _QuickGrid extends StatelessWidget {
  final int musicCount;
  final int videoCount;
  final int downloadCount;
  const _QuickGrid({required this.musicCount, required this.videoCount, required this.downloadCount});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (Icons.music_note_rounded, 'Music', '$musicCount tracks', '/music'),
      (Icons.movie_rounded, 'Video', '$videoCount files', '/library'),
      (Icons.download_rounded, 'Downloads', '$downloadCount files', '/downloads'),
      (Icons.auto_awesome_rounded, 'OTYA AI', 'Ask anything', '/ai'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.35,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return InkWell(
            onTap: () => context.go(card.$4),
            borderRadius: BorderRadius.circular(17),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                color: Theme.of(context).colorScheme.surface.withValues(alpha: .78),
                border: Border.all(color: AppColors.accent.withValues(alpha: .13)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [AppColors.accent.withValues(alpha: .95), const Color(0xFFFF2CAA).withValues(alpha: .8)],
                      ),
                    ),
                    child: Icon(card.$1, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.$2, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        Text(card.$3,
                            maxLines: 1,
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55))),
                      ],
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
        leading: _Art(item: item, size: 48, radius: 12),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(item.artist ?? item.album ?? item.formattedDuration,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.more_vert_rounded, size: 20),
        onTap: () => _open(context, item),
      );
}

class _VideoRail extends StatelessWidget {
  final List<MediaItem> items;
  const _VideoRail({required this.items});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 165,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: () => _open(context, item),
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Art(item: item, size: 190, height: 108, radius: 16),
                    const SizedBox(height: 7),
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(item.formattedDuration,
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55))),
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
      return AlbumArtThumb(albumArtPath: item.albumArtPath, size: height ?? size, borderRadius: radius);
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
              Image.file(File(path), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _videoPlaceholder(context))
            else
              _videoPlaceholder(context),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: .55),
                  border: Border.all(color: Colors.white.withValues(alpha: .5)),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
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
        child: const Icon(Icons.movie_rounded, color: AppColors.accent, size: 32),
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
          IconButton(onPressed: () => query = '', icon: const Icon(Icons.close_rounded)),
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
          leading: _Art(item: item, size: 46, radius: 11),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.isVideo ? 'Video · ${item.formattedDuration}' : (item.artist ?? 'Music')),
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
              const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.error),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

bool _isDownloaded(MediaItem item) {
  final p = item.filePath.toLowerCase();
  return p.contains('/download/') || p.contains('/downloads/');
}

void _open(BuildContext context, MediaItem item) {
  context.push(item.isVideo ? '/player/video' : '/player/audio', extra: item);
}
