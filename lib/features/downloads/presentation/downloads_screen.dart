import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../../../shared/widgets/album_art_thumb.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';

enum _DownloadFilter { all, music, video }

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  _DownloadFilter _filter = _DownloadFilter.all;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(mediaLibraryProvider);
    return WallpaperScaffold(
      body: SafeArea(
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) {
            final downloads = items.where(_isDownloaded).toList()
              ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
            final visible = switch (_filter) {
              _DownloadFilter.music => downloads.where((e) => !e.isVideo).toList(),
              _DownloadFilter.video => downloads.where((e) => e.isVideo).toList(),
              _DownloadFilter.all => downloads,
            };
            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => ref.read(mediaLibraryProvider.notifier).refresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _Header(count: downloads.length)),
                  SliverToBoxAdapter(child: _StorageCard(items: downloads)),
                  SliverToBoxAdapter(
                    child: _Filters(
                      current: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                  ),
                  if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyDownloads(),
                    )
                  else
                    SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) => _DownloadTile(item: visible[index]),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 130)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Downloads',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('$count local files in your Downloads folders',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55),
                          )),
                ],
              ),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
            IconButton(onPressed: () => context.push('/tools/folders'), icon: const Icon(Icons.more_vert_rounded)),
          ],
        ),
      );
}

class _StorageCard extends StatelessWidget {
  final List<MediaItem> items;
  const _StorageCard({required this.items});

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final bytes = items.fold<int>(0, (sum, item) => sum + item.fileSizeBytes);
    final music = items.where((e) => !e.isVideo).fold<int>(0, (sum, e) => sum + e.fileSizeBytes);
    final video = items.where((e) => e.isVideo).fold<int>(0, (sum, e) => sum + e.fileSizeBytes);
    final total = bytes <= 0 ? 1 : bytes;
    final musicRatio = music / total;
    final videoRatio = video / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
        border: Border.all(color: AppColors.accent.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text('Downloaded media', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(_size(bytes), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  if (musicRatio > 0)
                    Expanded(
                      flex: (musicRatio * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: Color(0xFF6B48FF)),
                    ),
                  if (videoRatio > 0)
                    Expanded(
                      flex: (videoRatio * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: Color(0xFF00CFFF)),
                    ),
                  if (bytes == 0)
                    const Expanded(child: ColoredBox(color: Color(0xFF242537))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Legend(color: const Color(0xFF6B48FF), text: 'Music ${_size(music)}'),
              const SizedBox(width: 16),
              _Legend(color: const Color(0xFF00CFFF), text: 'Video ${_size(video)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _Filters extends StatelessWidget {
  final _DownloadFilter current;
  final ValueChanged<_DownloadFilter> onChanged;
  const _Filters({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SegmentedButton<_DownloadFilter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _DownloadFilter.all, label: Text('All')),
            ButtonSegment(value: _DownloadFilter.music, label: Text('Music')),
            ButtonSegment(value: _DownloadFilter.video, label: Text('Video')),
          ],
          selected: {current},
          onSelectionChanged: (value) => onChanged(value.first),
        ),
      );
}

class _DownloadTile extends StatelessWidget {
  final MediaItem item;
  const _DownloadTile({required this.item});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
        leading: item.isVideo ? _VideoThumb(item: item) : AlbumArtThumb(albumArtPath: item.albumArtPath, size: 50, borderRadius: 12),
        title: Text(item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text('${item.isVideo ? 'Video' : (item.artist ?? 'Music')} · ${item.formattedSize}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF24D789), size: 19),
        onTap: () => context.push(item.isVideo ? '/player/video' : '/player/audio', extra: item),
      );
}

class _VideoThumb extends StatelessWidget {
  final MediaItem item;
  const _VideoThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final path = item.thumbnailPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 50,
        height: 50,
        child: path != null && path.isNotEmpty
            ? Image.file(File(path), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF1A1B29),
                      child: Icon(Icons.movie_rounded, color: AppColors.accent),
                    ))
            : const ColoredBox(
                color: Color(0xFF1A1B29),
                child: Icon(Icons.movie_rounded, color: AppColors.accent),
              ),
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: .12),
                ),
                child: const Icon(Icons.download_done_rounded, color: AppColors.accent, size: 34),
              ),
              const SizedBox(height: 16),
              const Text('No downloaded media found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Files stored in your device Download or Downloads folders will appear here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55)),
              ),
            ],
          ),
        ),
      );
}

bool _isDownloaded(MediaItem item) {
  final p = item.filePath.toLowerCase();
  return p.contains('/download/') || p.contains('/downloads/');
}
