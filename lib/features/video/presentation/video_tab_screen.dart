import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../shared/widgets/media_new_indicator.dart';
import '../../../shared/widgets/permission_denied_screen.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../../player/presentation/queue_screen.dart';
import '../../search/smart_search_sheet.dart';

enum _VideoView { videos, folders, playlists }
final _videoViewProvider = StateProvider<_VideoView>((_) => _VideoView.videos);

class VideoTabScreen extends ConsumerStatefulWidget {
  const VideoTabScreen({super.key});

  @override
  ConsumerState<VideoTabScreen> createState() => _VideoTabScreenState();
}

class _VideoTabScreenState extends ConsumerState<VideoTabScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(mediaLibraryProvider.notifier).backgroundRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final library = ref.watch(mediaLibraryProvider);
    final view = ref.watch(_videoViewProvider);
    return WallpaperScaffold(
      body: SafeArea(
        child: library.when(
          loading: () {
            final cached = library.valueOrNull;
            return cached == null
                ? const Center(child: CircularProgressIndicator())
                : _content(context, cached, view);
          },
          error: (error, _) {
            if (error.toString().toLowerCase().contains('permission')) {
              return PermissionDeniedScreen(
                onRetry: () => ref.read(mediaLibraryProvider.notifier).refresh(),
              );
            }
            return _VideoError(
              onRetry: () => ref.read(mediaLibraryProvider.notifier).refresh(),
            );
          },
          data: (items) => RefreshIndicator(
            onRefresh: () => ref.read(mediaLibraryProvider.notifier).refresh(),
            child: _content(context, items, view),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<MediaItem> items, _VideoView view) {
    final videos = items.where((item) => item.isVideo).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: _VideoHeader(count: videos.length)),
        SliverToBoxAdapter(child: _VideoPicker(value: view)),
        if (videos.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyVideo())
        else if (view == _VideoView.videos)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            sliver: SliverList.builder(
              itemCount: videos.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 3, 4, 9),
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        final queue = List<MediaItem>.from(videos)..shuffle();
                        _playVideo(context, queue, 0);
                      },
                      icon: const Icon(Icons.shuffle_rounded),
                      label: Text('Shuffle ${videos.length} video${videos.length == 1 ? '' : 's'}'),
                    ),
                  );
                }
                final videoIndex = index - 1;
                return _VideoTile(
                  item: videos[videoIndex],
                  onTap: () => _playVideo(context, videos, videoIndex),
                );
              },
            ),
          )
        else if (view == _VideoView.folders)
          _folderSliver(context, videos)
        else
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.playlist_play_rounded, size: 56, color: AppColors.accent),
                    const SizedBox(height: 14),
                    const Text('Playlists are shared across OTYA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    const Text('A playlist can contain local video or audio. Manage them from one Playlists screen.', textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => context.push('/playlists'),
                      icon: const Icon(Icons.queue_music_rounded),
                      label: const Text('Open Playlists'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 26)),
      ],
    );
  }

  SliverList _folderSliver(BuildContext context, List<MediaItem> videos) {
    final folders = <String, List<MediaItem>>{};
    for (final item in videos) {
      final normalized = item.filePath.replaceAll('\\', '/').split('/');
      final folder = normalized.length >= 2 ? normalized[normalized.length - 2].trim() : 'Device';
      folders.putIfAbsent(folder.isEmpty ? 'Device' : folder, () => <MediaItem>[]).add(item);
    }
    final entries = folders.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: const Icon(Icons.folder_rounded, color: AppColors.accent),
          ),
          title: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${entry.value.length} video${entry.value.length == 1 ? '' : 's'}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/video/folder', extra: {'name': entry.key, 'items': entry.value}),
        );
      },
    );
  }

  void _playVideo(BuildContext context, List<MediaItem> queue, int index) {
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    HapticFeedback.lightImpact();
    ref.read(queueProvider.notifier).setQueue(queue, startIndex: index);
    context.push('/player/video', extra: queue[index]);
  }
}

class VideoFolderDetailPage extends ConsumerWidget {
  const VideoFolderDetailPage({super.key, required this.name, required this.items});
  final String name;
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = items.where((item) => item.isVideo).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(name),
      ),
      body: videos.isEmpty
          ? const Center(child: Text('No videos are available in this folder.'))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.paddingOf(context).bottom + 24),
              itemCount: videos.length,
              itemBuilder: (context, index) => _VideoTile(
                item: videos[index],
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(queueProvider.notifier).setQueue(videos, startIndex: index);
                  context.push('/player/video', extra: videos[index]);
                },
              ),
            ),
    );
  }
}

class _VideoHeader extends StatelessWidget {
  const _VideoHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/icons/play_store_512.png', width: 38, height: 38),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Video', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                  Text('$count local video${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Search OTYA',
              onPressed: () {
                HapticFeedback.selectionClick();
                SmartSearchSheet.show(context);
              },
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'History',
              onPressed: () => context.push('/history'),
              icon: const Icon(Icons.history_rounded),
            ),
          ],
        ),
      );
}

class _VideoPicker extends ConsumerWidget {
  const _VideoPicker({required this.value});
  final _VideoView value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = [
      (_VideoView.videos, 'Videos'),
      (_VideoView.folders, 'Folders'),
      (_VideoView.playlists, 'Playlists'),
    ];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final option = options[index];
          return ChoiceChip(
            selected: option.$1 == value,
            label: Text(option.$2),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              ref.read(_videoViewProvider.notifier).state = option.$1;
            },
          );
        },
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.item, required this.onTap});
  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: _VideoThumb(item: item),
          title: Row(
            children: [
              Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              MediaNewIndicator(item: item),
            ],
          ),
          subtitle: Text('${item.formattedDuration} · ${item.formattedSize}', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.accent),
          onTap: onTap,
        ),
      );
}

class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.item});
  final MediaItem item;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  static const _channel = MethodChannel('com.otyaplayer.app/media_store');
  static final Map<String, String?> _cache = <String, String?>{};
  String? _path;

  @override
  void initState() {
    super.initState();
    _path = widget.item.thumbnailPath ?? _cache[widget.item.id];
    if (_path == null) _load();
  }

  Future<void> _load() async {
    try {
      final path = await _channel.invokeMethod<String>('getVideoThumbnail', {
        'path': widget.item.filePath,
        'id': widget.item.mediaStoreId ?? '',
      }).timeout(const Duration(seconds: 5));
      _cache[widget.item.id] = path;
      if (mounted) setState(() => _path = path);
    } catch (_) {
      _cache[widget.item.id] = null;
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 74,
          height: 48,
          child: _path != null && File(_path!).existsSync()
              ? Image.file(File(_path!), fit: BoxFit.cover, cacheWidth: 240, errorBuilder: (_, __, ___) => _placeholder(context))
              : _placeholder(context),
        ),
      );

  Widget _placeholder(BuildContext context) => Container(
        color: AppColors.cardOf(context),
        alignment: Alignment.center,
        child: const Icon(Icons.movie_rounded, color: AppColors.accent),
      );
}

class _EmptyVideo extends StatelessWidget {
  const _EmptyVideo();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_outlined, size: 58, color: AppColors.accent),
              SizedBox(height: 14),
              Text('No videos found', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              Text('OTYA shows playable video discovered by Android MediaStore. Check media permissions if videos are missing.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _VideoError extends StatelessWidget {
  const _VideoError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 50, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('OTYA could not refresh your video library.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      );
}
