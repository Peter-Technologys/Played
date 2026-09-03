import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../shared/widgets/album_art_thumb.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../../player/presentation/mini_player.dart';
import '../../player/presentation/queue_screen.dart';
import '../../search/smart_search_sheet.dart';

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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/tools/folders'),
        ),
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Search OTYA',
            onPressed: () => SmartSearchSheet.show(context),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: library.when(
        loading: () {
          final cached = library.valueOrNull;
          return cached == null
              ? const Center(child: CircularProgressIndicator())
              : _body(context, cached);
        },
        error: (_, __) => Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.read(mediaLibraryProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry media scan'),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.read(mediaLibraryProvider.notifier).refresh(),
          child: _body(context, items),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<MediaItem> all) {
    final downloads = all.where(_isDownloaded).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final visible = switch (_filter) {
      _DownloadFilter.music => downloads.where((item) => !item.isVideo).toList(),
      _DownloadFilter.video => downloads.where((item) => item.isVideo).toList(),
      _DownloadFilter.all => downloads,
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        _Summary(downloads: downloads),
        const SizedBox(height: 12),
        SegmentedButton<_DownloadFilter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _DownloadFilter.all, label: Text('All')),
            ButtonSegment(value: _DownloadFilter.music, label: Text('Music')),
            ButtonSegment(value: _DownloadFilter.video, label: Text('Video')),
          ],
          selected: {_filter},
          onSelectionChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _filter = value.first);
          },
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 70),
            child: Column(
              children: [
                Icon(Icons.download_done_rounded, size: 55, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text('No downloaded media found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('Playable files in Download or Downloads appear automatically in Video or Music after Android indexes them.', textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ...List.generate(visible.length, (index) {
            final item = visible[index];
            return _DownloadTile(
              item: item,
              onTap: () => _play(item, visible, index),
            );
          }),
      ],
    );
  }

  void _play(MediaItem item, List<MediaItem> visible, int index) {
    HapticFeedback.lightImpact();
    final sameType = visible.where((candidate) => candidate.isVideo == item.isVideo).toList();
    final actualIndex = sameType.indexWhere((candidate) => candidate.id == item.id);
    ref.read(queueProvider.notifier).setQueue(sameType, startIndex: actualIndex < 0 ? 0 : actualIndex);
    if (item.isVideo) {
      context.push('/player/video', extra: item);
    } else {
      ref.read(miniPlayerItemProvider.notifier).state = item;
      context.push('/player/audio', extra: item);
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.downloads});
  final List<MediaItem> downloads;

  @override
  Widget build(BuildContext context) {
    final bytes = downloads.fold<int>(0, (sum, item) => sum + item.fileSizeBytes);
    final videos = downloads.where((item) => item.isVideo).length;
    final music = downloads.length - videos;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.download_rounded, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${downloads.length} downloaded media file${downloads.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('$music audio · $videos video', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(_formatBytes(bytes), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.item, required this.onTap});
  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        leading: item.isVideo
            ? _VideoThumb(item: item)
            : AlbumArtThumb(albumArtPath: item.albumArtPath, size: 48, borderRadius: 12),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${item.isVideo ? 'Video' : (item.artist?.trim().isNotEmpty == true ? item.artist!.trim() : 'Audio')} · ${item.formattedSize}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.accent),
        onTap: onTap,
      );
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final path = item.thumbnailPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 68,
        height: 48,
        child: path != null && path.isNotEmpty
            ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: 220, errorBuilder: (_, __, ___) => _placeholder(context))
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: AppColors.cardOf(context),
        alignment: Alignment.center,
        child: const Icon(Icons.movie_rounded, color: AppColors.accent),
      );
}

bool _isDownloaded(MediaItem item) {
  final path = item.filePath.toLowerCase().replaceAll('\\', '/');
  return path.contains('/download/') || path.contains('/downloads/');
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}