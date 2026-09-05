import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_colors.dart';
import '../../core/database/otya_database.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
import '../../shared/widgets/album_art_thumb.dart';
import '../../shared/widgets/otya_logo.dart';
import '../../shared/widgets/wallpaper_scaffold.dart';
import '../my_space/presentation/providers/my_space_provider.dart';
import '../player/presentation/mini_player.dart';
import '../player/presentation/queue_screen.dart';

final playlistsProvider = StateNotifierProvider<PlaylistsNotifier, List<Playlist>>(
  (ref) => PlaylistsNotifier()..load(),
);

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier() : super(const []);

  void load() {
    state = OtyaDatabase.instance.getAllPlaylists()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<Playlist> create(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Playlist name cannot be empty');
    final now = DateTime.now();
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: clean,
      mediaIds: <String>[],
      createdAt: now,
      updatedAt: now,
    );
    await OtyaDatabase.instance.savePlaylist(playlist);
    load();
    return playlist;
  }

  Future<void> rename(String id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final current = OtyaDatabase.instance.getPlaylist(id);
    if (current == null) return;
    await OtyaDatabase.instance.savePlaylist(
      Playlist(
        id: current.id,
        name: clean,
        mediaIds: List<String>.from(current.mediaIds),
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
        coverMediaId: current.coverMediaId,
      ),
    );
    load();
  }

  Future<Playlist?> delete(String id) async {
    final current = OtyaDatabase.instance.getPlaylist(id);
    if (current == null) return null;
    final snapshot = Playlist(
      id: current.id,
      name: current.name,
      mediaIds: List<String>.from(current.mediaIds),
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      coverMediaId: current.coverMediaId,
    );
    await OtyaDatabase.instance.deletePlaylist(id);
    load();
    return snapshot;
  }

  Future<void> restore(Playlist playlist) async {
    await OtyaDatabase.instance.savePlaylist(
      Playlist(
        id: playlist.id,
        name: playlist.name,
        mediaIds: List<String>.from(playlist.mediaIds),
        createdAt: playlist.createdAt,
        updatedAt: DateTime.now(),
        coverMediaId: playlist.coverMediaId,
      ),
    );
    load();
  }

  Future<void> addTrack(String playlistId, MediaItem item) async {
    await OtyaDatabase.instance.addToPlaylist(playlistId, item);
    load();
  }

  Future<void> removeTrack(String playlistId, String mediaId) async {
    final current = OtyaDatabase.instance.getPlaylist(playlistId);
    if (current == null || !current.mediaIds.contains(mediaId)) return;
    await OtyaDatabase.instance.savePlaylist(
      Playlist(
        id: current.id,
        name: current.name,
        mediaIds: current.mediaIds.where((id) => id != mediaId).toList(),
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
        coverMediaId:
            current.coverMediaId == mediaId ? null : current.coverMediaId,
      ),
    );
    load();
  }
}

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return WallpaperScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/myspace'),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OtyaMark(size: 28),
            SizedBox(width: 9),
            Text('Playlists'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New playlist',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _createPlaylist(context, ref),
          ),
        ],
      ),
      body: playlists.isEmpty
          ? _EmptyPlaylists(onCreate: () => _createPlaylist(context, ref))
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.read(playlistsProvider.notifier).load(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.paddingOf(context).bottom + 30,
                ),
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return Dismissible(
                    key: ValueKey(playlist.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) =>
                        _confirmDelete(context, playlist.name),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) async {
                      final snapshot = await ref
                          .read(playlistsProvider.notifier)
                          .delete(playlist.id);
                      if (!context.mounted || snapshot == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('“${snapshot.name}” deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => ref
                                .read(playlistsProvider.notifier)
                                .restore(snapshot),
                          ),
                        ),
                      );
                    },
                    child: _PlaylistCard(
                      playlist: playlist,
                      onTap: () => context.push('/playlist/${playlist.id}'),
                      onRename: () =>
                          _renamePlaylist(context, ref, playlist),
                      onDelete: () async {
                        if (!await _confirmDelete(context, playlist.name)) {
                          return;
                        }
                        final snapshot = await ref
                            .read(playlistsProvider.notifier)
                            .delete(playlist.id);
                        if (!context.mounted || snapshot == null) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('“${snapshot.name}” deleted'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => ref
                                  .read(playlistsProvider.notifier)
                                  .restore(snapshot),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class PlaylistDetailScreenById extends ConsumerWidget {
  const PlaylistDetailScreenById({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref
        .watch(playlistsProvider)
        .where((entry) => entry.id == playlistId)
        .firstOrNull;
    if (playlist == null) {
      return WallpaperScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/playlists'),
          ),
          title: const Text('Playlist'),
        ),
        body: const Center(child: Text('This playlist no longer exists.')),
      );
    }
    return PlaylistDetailScreen(playlist: playlist);
  }
}

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library =
        ref.watch(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[];
    final byId = {for (final item in library) item.id: item};
    final tracks = playlist.mediaIds
        .map((id) => byId[id])
        .whereType<MediaItem>()
        .toList(growable: false);
    final missingCount = playlist.mediaIds.length - tracks.length;
    final currentId = ref.watch(queueProvider.select((queue) => queue.current?.id));
    final videoCount = tracks.where((item) => item.isVideo).length;
    final audioCount = tracks.length - videoCount;

    return WallpaperScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/playlists'),
        ),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Add media',
            onPressed: () => _addMedia(context, ref, playlist, library),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: tracks.isEmpty
          ? _EmptyPlaylistDetail(
              missingCount: missingCount,
              onAdd: () => _addMedia(context, ref, playlist, library),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.paddingOf(context).bottom + 28,
              ),
              children: [
                _PlaylistSummary(
                  total: tracks.length,
                  videos: videoCount,
                  audio: audioCount,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _play(context, ref, tracks, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final shuffled = List<MediaItem>.from(tracks)
                            ..shuffle();
                          _play(context, ref, shuffled, 0);
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                      ),
                    ),
                  ],
                ),
                if (missingCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '$missingCount saved item${missingCount == 1 ? '' : 's'} '
                    'could not be found on this device.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ...List.generate(tracks.length, (index) {
                  final item = tracks[index];
                  final isCurrent = currentId == item.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: item.isVideo
                        ? _DetailedVideoPlaylistCard(
                            item: item,
                            isCurrent: isCurrent,
                            onTap: () => _play(context, ref, tracks, index),
                            onRemove: () => ref
                                .read(playlistsProvider.notifier)
                                .removeTrack(playlist.id, item.id),
                          )
                        : _DetailedAudioPlaylistCard(
                            item: item,
                            isCurrent: isCurrent,
                            onTap: () => _play(context, ref, tracks, index),
                            onRemove: () => ref
                                .read(playlistsProvider.notifier)
                                .removeTrack(playlist.id, item.id),
                          ),
                  );
                }),
              ],
            ),
    );
  }
}

void _play(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> queue,
  int index,
) {
  if (queue.isEmpty || index < 0 || index >= queue.length) return;
  HapticFeedback.lightImpact();
  final item = queue[index];
  ref.read(queueProvider.notifier).setQueue(queue, startIndex: index);
  if (item.isVideo) {
    context.push('/player/video', extra: item);
  } else {
    ref.read(miniPlayerItemProvider.notifier).state = item;
    context.push('/player/audio', extra: item);
  }
}

Future<void> _addMedia(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
  List<MediaItem> library,
) async {
  if (library.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No local media is available to add.')),
    );
    return;
  }
  final existing = playlist.mediaIds.toSet();
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .84,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add local media',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Expanded(
            child: StatefulBuilder(
              builder: (context, setSheetState) => ListView.builder(
                itemCount: library.length,
                itemBuilder: (context, index) {
                  final item = library[index];
                  final added = existing.contains(item.id);
                  return ListTile(
                    leading: item.isVideo
                        ? const Icon(Icons.movie_outlined)
                        : AlbumArtThumb(
                            albumArtPath: item.albumArtPath,
                            size: 42,
                            borderRadius: 10,
                          ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item.isVideo ? 'Video' : item.artist ?? 'Audio'} • '
                      '${item.formattedDuration} • ${item.formattedSize}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      added
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      color: added ? AppColors.accentGreen : AppColors.accent,
                    ),
                    enabled: !added,
                    onTap: added
                        ? null
                        : () async {
                            await ref
                                .read(playlistsProvider.notifier)
                                .addTrack(playlist.id, item);
                            setSheetState(() => existing.add(item.id));
                          },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlaylistSummary extends StatelessWidget {
  const _PlaylistSummary({
    required this.total,
    required this.videos,
    required this.audio,
  });

  final int total;
  final int videos;
  final int audio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          const OtyaMark(size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total local ${total == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$videos video${videos == 1 ? '' : 's'} • '
                  '$audio song${audio == 1 ? '' : 's'} • Offline',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailedVideoPlaylistCard extends StatelessWidget {
  const _DetailedVideoPlaylistCard({
    required this.item,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  final MediaItem item;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final progress = _resumeProgress(item);
    return Semantics(
      button: true,
      label: '${item.title}, video, ${item.formattedDuration}',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCurrent
                  ? AppColors.brandCyan.withValues(alpha: .85)
                  : AppColors.borderOf(context),
              width: isCurrent ? 1.5 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: .20),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(23),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _VideoPlaylistThumb(item: item),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB8050812)],
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _StatusPill(
                            icon: Icons.graphic_eq_rounded,
                            label: 'NOW PLAYING',
                          ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: _MetaPill(label: item.formattedDuration),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(
                                Icons.folder_rounded,
                                size: 16,
                                color: AppColors.brandCyan,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _folderName(item.filePath),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _MetaPill(label: item.formattedSize),
                              _MetaPill(label: item.formattedDuration),
                              _MetaPill(label: _addedLabel(item.addedAt)),
                            ],
                          ),
                          if (progress > 0) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor:
                                    Colors.white.withValues(alpha: .08),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.brandCyan,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              progress >= .96
                                  ? 'Watched'
                                  : 'Continue • ${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Video options',
                      onSelected: (action) {
                        if (action == 'remove') onRemove();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from playlist'),
                        ),
                      ],
                    ),
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

class _DetailedAudioPlaylistCard extends StatelessWidget {
  const _DetailedAudioPlaylistCard({
    required this.item,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  final MediaItem item;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCurrent
                ? AppColors.brandCyan.withValues(alpha: .75)
                : AppColors.borderOf(context),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                AlbumArtThumb(
                  albumArtPath: item.albumArtPath,
                  size: 78,
                  borderRadius: 18,
                ),
                if (isCurrent)
                  const Positioned(
                    right: 6,
                    bottom: 6,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.brandBlue,
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.artist ?? 'Unknown artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    children: [
                      _MetaPill(label: item.formattedDuration),
                      _MetaPill(label: item.formattedSize),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Song options',
              onSelected: (action) {
                if (action == 'remove') onRemove();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from playlist'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaylistThumb extends StatelessWidget {
  const _VideoPlaylistThumb({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final path = item.thumbnailPath;
    if (path == null || path.isEmpty) return _placeholder();
    final decodeWidth =
        (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 2048);
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(gradient: AppColors.accentGradientDiag),
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_rounded,
          color: Colors.white,
          size: 48,
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: .28),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: .05)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradientDiag,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${playlist.mediaIds.length} local '
                      '${playlist.mediaIds.length == 1 ? 'item' : 'items'} • Offline',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'rename') onRename();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      );
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OtyaMark(size: 72),
              const SizedBox(height: 18),
              const Text(
                'No playlists yet',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a local playlist for your own music and videos. '
                'It works without an account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create playlist'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyPlaylistDetail extends StatelessWidget {
  const _EmptyPlaylistDetail({
    required this.missingCount,
    required this.onAdd,
  });

  final int missingCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.playlist_add_rounded,
                size: 58,
                color: AppColors.brandCyan,
              ),
              const SizedBox(height: 14),
              Text(
                missingCount > 0
                    ? 'Saved files are missing'
                    : 'This playlist is empty',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                missingCount > 0
                    ? 'The playlist is intact, but its saved files are not '
                        'currently available on this device.'
                    : 'Add your local songs or videos to begin.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add media'),
              ),
            ],
          ),
        ),
      );
}

Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
  final name =
      await _askName(context, title: 'New playlist', action: 'Create');
  if (name == null) return;
  await ref.read(playlistsProvider.notifier).create(name);
}

Future<void> _renamePlaylist(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final name = await _askName(
    context,
    title: 'Rename playlist',
    action: 'Save',
    initial: playlist.name,
  );
  if (name == null) return;
  await ref.read(playlistsProvider.notifier).rename(playlist.id, name);
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) {
          final clean = value.trim();
          if (clean.isNotEmpty) Navigator.pop(dialogContext, clean);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final clean = controller.text.trim();
            if (clean.isNotEmpty) Navigator.pop(dialogContext, clean);
          },
          child: Text(action),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> _confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          'Delete “$name”? The media files themselves are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

double _resumeProgress(MediaItem item) {
  final duration = item.duration;
  if (duration == null || duration.inMilliseconds <= 0) return 0;
  final position = OtyaDatabase.instance.getSeekPosition(item.id);
  if (position == null || position <= Duration.zero) return 0;
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

String _folderName(String rawPath) {
  final parts = rawPath.replaceAll('\\', '/').split('/');
  if (parts.length < 2) return 'Device';
  final folder = parts[parts.length - 2].trim();
  return folder.isEmpty ? 'Device' : folder;
}

String _addedLabel(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inDays == 0) return 'Today';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
  return '${date.day}/${date.month}/${date.year}';
}