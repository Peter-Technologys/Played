import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../../player/presentation/queue_screen.dart';
import '../../../shared/widgets/album_art_thumb.dart';
import '../../../shared/widgets/playlists_view.dart';

// ── Filter pill state ─────────────────────────────────────────────────────

enum _MusicFilter { allSongs, playlist, folder, album, artist }

final _musicFilterProvider =
    StateProvider<_MusicFilter>((_) => _MusicFilter.allSongs);

// ── Now-playing highlight ─────────────────────────────────────────────────

final _musicNowPlayingIdProvider = StateProvider<String?>((_) => null);

// ── Sorted songs provider ─────────────────────────────────────────────────
// Derived provider so the sort runs once when data arrives, not on every
// build. Riverpod caches the result until mediaLibraryProvider changes.
final _sortedSongsProvider = Provider<List<MediaItem>>((ref) {
  final items = ref.watch(mediaLibraryProvider).valueOrNull ?? [];
  final songs = items.where((e) => !e.isVideo).toList();
  songs.sort((a, b) => a.title.compareTo(b.title));
  return songs;
});

// ── Music Tab Screen ──────────────────────────────────────────────────────

class MusicTabScreen extends ConsumerStatefulWidget {
  const MusicTabScreen({super.key});

  @override
  ConsumerState<MusicTabScreen> createState() => _MusicTabScreenState();
}

class _MusicTabScreenState extends ConsumerState<MusicTabScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  Timer? _refreshDebounce;

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
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(seconds: 2), () {
        ref.read(mediaLibraryProvider.notifier).backgroundRefresh();
      });
    }
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final libraryAsync = ref.watch(mediaLibraryProvider);
    final filter = ref.watch(_musicFilterProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _MusicHeader(libraryAsync: libraryAsync),

            // ── Filter pills ─────────────────────────────────────────
            _FilterPills(current: filter),

            // ── Content ──────────────────────────────────────────────
            Expanded(
              child: libraryAsync.when(
                loading: () => libraryAsync.valueOrNull != null
                    ? _buildContent(
                        context, libraryAsync.valueOrNull!, filter)
                    : const _MusicShimmer(),
                error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(mediaLibraryProvider.notifier).refresh(),
                ),
                data: (items) => RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: () => ref
                      .read(mediaLibraryProvider.notifier)
                      .backgroundRefresh(),
                  child: _buildContent(context, items, filter),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<MediaItem> items, _MusicFilter filter) {
    // Use the pre-sorted provider to avoid re-sorting on every build.
    final songs = ref.watch(_sortedSongsProvider);

    switch (filter) {
      case _MusicFilter.allSongs:
        return _SongListView(songs: songs);
      case _MusicFilter.playlist:
        return const PlaylistsView(showCreateButton: false);
      case _MusicFilter.folder:
        return _FoldersView(songs: songs);
      case _MusicFilter.album:
        return _AlbumsView(songs: songs);
      case _MusicFilter.artist:
        return _ArtistsView(songs: songs);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _MusicHeader extends ConsumerWidget {
  final AsyncValue<List<MediaItem>> libraryAsync;
  const _MusicHeader({required this.libraryAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs =
        libraryAsync.valueOrNull?.where((e) => !e.isVideo).toList();
    final count = songs?.length ?? 0;
    final isScanning =
        libraryAsync.isLoading && libraryAsync.valueOrNull != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentViolet, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [AppColors.accentViolet, AppColors.accent],
                  ).createShader(b),
                  child: const Text(
                    'Music Library',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Inter',
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (count > 0)
                      Text(
                        '$count song${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    if (isScanning) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.accentViolet,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Search
          _IconBtn(
            icon: Icons.search_rounded,
            onTap: () {
              final items =
                  ref.read(mediaLibraryProvider).valueOrNull ?? [];
              final songs = items.where((e) => !e.isVideo).toList();
              showSearch(
                context: context,
                delegate: _MusicSearchDelegate(
                  songs: songs,
                  onPlay: (queue, index, item) {
                    ref
                        .read(queueProvider.notifier)
                        .setQueue(queue, startIndex: index);
                    ref
                        .read(_musicNowPlayingIdProvider.notifier)
                        .state = item.id;
                    context.push('/player/audio', extra: item);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          // Refresh
          _IconBtn(
            icon: Icons.refresh_rounded,
            onTap: () =>
                ref.read(mediaLibraryProvider.notifier).backgroundRefresh(),
          ),
        ],
      ),
    );
  }
}

// ── Filter pills ──────────────────────────────────────────────────────────

class _FilterPills extends ConsumerWidget {
  final _MusicFilter current;
  const _FilterPills({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const pills = [
      (_MusicFilter.allSongs, 'All Songs'),
      (_MusicFilter.playlist, 'Playlist'),
      (_MusicFilter.folder, 'Folder'),
      (_MusicFilter.album, 'Album'),
      (_MusicFilter.artist, 'Artist'),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (filter, label) = pills[i];
          final isActive = current == filter;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(_musicFilterProvider.notifier).state = filter;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [AppColors.accentViolet, AppColors.accent],
                      )
                    : null,
                color: isActive ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? Colors.transparent
                      : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Song List View ────────────────────────────────────────────────────────

class _SongListView extends ConsumerWidget {
  final List<MediaItem> songs;
  const _SongListView({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return const _EmptyState(
          icon: Icons.music_note_rounded, label: 'No songs found');
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Shuffle all action bar
        SliverToBoxAdapter(
          child: _ShuffleBar(songs: songs),
        ),

        // Song list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final item = songs[i];
                return _SongRow(
                  item: item,
                  index: i,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(queueProvider.notifier)
                        .setQueue(songs, startIndex: i);
                    ref
                        .read(_musicNowPlayingIdProvider.notifier)
                        .state = item.id;
                    context.push('/player/audio', extra: item);
                  },
                );
              },
              childCount: songs.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shuffle bar ───────────────────────────────────────────────────────────

class _ShuffleBar extends ConsumerWidget {
  final List<MediaItem> songs;
  const _ShuffleBar({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: () {
          if (songs.isEmpty) return;
          HapticFeedback.lightImpact();
          final shuffled = List.of(songs)..shuffle();
          ref.read(queueProvider.notifier).setQueue(shuffled);
          ref.read(_musicNowPlayingIdProvider.notifier).state =
              shuffled.first.id;
          context.push('/player/audio', extra: shuffled.first);
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accentViolet, AppColors.accent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentViolet.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shuffle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Shuffle all (${songs.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Song Row ──────────────────────────────────────────────────────────────

class _SongRow extends ConsumerWidget {
  final MediaItem item;
  final int index;
  final VoidCallback onTap;
  const _SongRow(
      {required this.item, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlayingId = ref.watch(_musicNowPlayingIdProvider);
    final isPlaying = nowPlayingId == item.id;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isPlaying
              ? AppColors.accentViolet.withValues(alpha: 0.06)
              : Colors.transparent,
          border: isPlaying
              ? const Border(
                  left: BorderSide(color: AppColors.accentViolet, width: 3))
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: isPlaying ? 13 : 16,
            right: 12,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: [
              // Track number
              SizedBox(
                width: 28,
                child: isPlaying
                    ? const _MiniWave()
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Album art
              AlbumArtThumb(albumArtPath: item.albumArtPath),
              const SizedBox(width: 12),
              // Title + artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isPlaying
                            ? AppColors.accentViolet
                            : AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.artist != null &&
                              item.artist!.isNotEmpty &&
                              item.artist != '<unknown>'
                          ? item.artist!
                          : 'Unknown Artist',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Duration
              SizedBox(
                width: 40,
                child: Text(
                  item.formattedDuration,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // 3-dot options menu
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showSongOptions(context, ref, item);
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongOptions(BuildContext context, WidgetRef ref, MediaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SongOptionsSheet(item: item, ref: ref),
    );
  }
}

// ── Song options bottom sheet ─────────────────────────────────────────────

class _SongOptionsSheet extends StatelessWidget {
  final MediaItem item;
  final WidgetRef ref;
  const _SongOptionsSheet({required this.item, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: AppColors.accentViolet, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary, fontFamily: 'Inter',
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(item.artist ?? 'Unknown Artist',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _OptionTile(
            icon: Icons.skip_next_rounded,
            label: 'Play Next',
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              ref.read(queueProvider.notifier).addToQueue(item);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to play next'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
          _OptionTile(
            icon: Icons.playlist_add_rounded,
            label: 'Add to Playlist',
            color: AppColors.accentViolet,
            onTap: () {
              Navigator.pop(context);
              context.push('/playlists');
            },
          ),
          _OptionTile(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppColors.accentGreen,
            onTap: () async {
              Navigator.pop(context);
              await Share.shareXFiles(
                [XFile(item.filePath)],
                text: item.title,
              );
            },
          ),
          _OptionTile(
            icon: Icons.info_outline_rounded,
            label: 'File Info',
            color: AppColors.textSecondary,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${item.title}\n${item.filePath}\n${item.formattedSize}',
                  ),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete not implemented'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
            fontSize: 14, color: AppColors.textPrimary,
            fontFamily: 'Inter', fontWeight: FontWeight.w500,
          )),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      dense: true,
    );
  }
}

// AlbumArtThumb is now in lib/shared/widgets/album_art_thumb.dart

// ── Mini waveform ─────────────────────────────────────────────────────────

class _MiniWave extends StatelessWidget {
  const _MiniWave();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return Container(
          width: 3,
          height: 12,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: AppColors.accentViolet,
            borderRadius: BorderRadius.circular(2),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleY(
              begin: 0.2,
              end: 1.0,
              duration: Duration(milliseconds: 300 + (i * 100)),
              curve: Curves.easeInOut,
            );
      }),
    );
  }
}

// PlaylistsView is now in lib/shared/widgets/playlists_view.dart

// ── Folders view ──────────────────────────────────────────────────────────

class _FoldersView extends ConsumerWidget {
  final List<MediaItem> songs;
  const _FoldersView({required this.songs});

  Map<String, List<MediaItem>> _buildFolders() {
    final map = <String, List<MediaItem>>{};
    for (final item in songs) {
      final parts = item.filePath.split('/');
      final folder = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('/')
          : '/';
      map.putIfAbsent(folder, () => []).add(item);
    }
    return map;
  }

  String _folderName(String path) {
    final parts = path.split('/');
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return const _EmptyState(
          icon: Icons.folder_open_rounded, label: 'No music folders found');
    }
    final folders = _buildFolders();
    final keys = folders.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final path = keys[i];
        final files = folders[path]!;
        final name = _folderName(path);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_rounded,
                  color: AppColors.accentViolet, size: 24),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${files.length} song${files.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () => context.push(
              '/music/folder',
              extra: {'name': name, 'items': files},
            ),
          ),
        );
      },
    );
  }
}

// Public so it can be referenced from router.dart via GoRoute.
class MusicFolderDetailPage extends ConsumerWidget {
  final String name;
  final List<MediaItem> items;
  const MusicFolderDetailPage({super.key, required this.name, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${items.length} song${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return _SongRow(
            item: item,
            index: i,
            onTap: () {
              HapticFeedback.lightImpact();
              ref
                  .read(queueProvider.notifier)
                  .setQueue(items, startIndex: i);
              context.push('/player/audio', extra: item);
            },
          );
        },
      ),
    );
  }
}

// ── Albums view ───────────────────────────────────────────────────────────

class _AlbumsView extends StatelessWidget {
  final List<MediaItem> songs;
  const _AlbumsView({required this.songs});

  Map<String, List<MediaItem>> _buildAlbums() {
    final map = <String, List<MediaItem>>{};
    for (final item in songs) {
      final album =
          (item.album?.isNotEmpty == true && item.album != '<unknown>')
              ? item.album!
              : 'Unknown Album';
      map.putIfAbsent(album, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const _EmptyState(
          icon: Icons.album_rounded, label: 'No albums found');
    }
    final albums = _buildAlbums();
    final keys = albums.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final album = keys[i];
        final tracks = albums[album]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentViolet, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.album_rounded,
                  color: Colors.white, size: 22),
            ),
            title: Text(
              album,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${tracks.length} track${tracks.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
        );
      },
    );
  }
}

// ── Artists view ──────────────────────────────────────────────────────────

class _ArtistsView extends StatelessWidget {
  final List<MediaItem> songs;
  const _ArtistsView({required this.songs});

  Map<String, List<MediaItem>> _buildArtists() {
    final map = <String, List<MediaItem>>{};
    for (final item in songs) {
      final artist =
          (item.artist?.isNotEmpty == true && item.artist != '<unknown>')
              ? item.artist!
              : 'Unknown Artist';
      map.putIfAbsent(artist, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const _EmptyState(
          icon: Icons.person_rounded, label: 'No artists found');
    }
    final artists = _buildArtists();
    final keys = artists.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final artist = keys[i];
        final tracks = artists[artist]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.accentViolet, size: 22),
            ),
            title: Text(
              artist,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${tracks.length} song${tracks.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
        );
      },
    );
  }
}

// ── Search delegate ───────────────────────────────────────────────────────

class _MusicSearchDelegate extends SearchDelegate<MediaItem?> {
  final List<MediaItem> songs;
  final void Function(List<MediaItem> queue, int index, MediaItem item) onPlay;
  _MusicSearchDelegate({required this.songs, required this.onPlay});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
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
    final q = query.toLowerCase();
    final results = q.isEmpty
        ? songs
        : songs
            .where((s) =>
                s.title.toLowerCase().contains(q) ||
                (s.artist?.toLowerCase().contains(q) ?? false) ||
                (s.album?.toLowerCase().contains(q) ?? false))
            .toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No songs found',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Container(
      color: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final item = results[i];
          return _SongRow(
            item: item,
            index: i,
            onTap: () {
              onPlay(results, i, item);
              close(context, item);
            },
          );
        },
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentViolet.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accentViolet, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Songs will appear here after scanning.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicShimmer extends StatelessWidget {
  const _MusicShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: 12,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                  width: 28,
                  height: 14,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14,
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(
                        width: 100,
                        height: 11,
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Could not load music',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentViolet,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
