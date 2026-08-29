import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_colors.dart';
import '../../core/database/otya_database.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
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
    await OtyaDatabase.instance.savePlaylist(Playlist(
      id: current.id,
      name: clean,
      mediaIds: List<String>.from(current.mediaIds),
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      coverMediaId: current.coverMediaId,
    ));
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
    await OtyaDatabase.instance.savePlaylist(Playlist(
      id: playlist.id,
      name: playlist.name,
      mediaIds: List<String>.from(playlist.mediaIds),
      createdAt: playlist.createdAt,
      updatedAt: DateTime.now(),
      coverMediaId: playlist.coverMediaId,
    ));
    load();
  }

  Future<void> addTrack(String playlistId, MediaItem item) async {
    await OtyaDatabase.instance.addToPlaylist(playlistId, item);
    load();
  }

  Future<void> removeTrack(String playlistId, String mediaId) async {
    final current = OtyaDatabase.instance.getPlaylist(playlistId);
    if (current == null || !current.mediaIds.contains(mediaId)) return;
    await OtyaDatabase.instance.savePlaylist(Playlist(
      id: current.id,
      name: current.name,
      mediaIds: current.mediaIds.where((id) => id != mediaId).toList(),
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      coverMediaId: current.coverMediaId == mediaId ? null : current.coverMediaId,
    ));
    load();
  }
}

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/myspace'),
        ),
        title: const Text('Playlists'),
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
              onRefresh: () async => ref.read(playlistsProvider.notifier).load(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 24),
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return Dismissible(
                    key: ValueKey(playlist.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(context, playlist.name),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 22),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      final snapshot = await ref.read(playlistsProvider.notifier).delete(playlist.id);
                      if (!context.mounted || snapshot == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('“${snapshot.name}” deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => ref.read(playlistsProvider.notifier).restore(snapshot),
                          ),
                        ),
                      );
                    },
                    child: _PlaylistCard(
                      playlist: playlist,
                      onTap: () => context.push('/playlist/${playlist.id}'),
                      onRename: () => _renamePlaylist(context, ref, playlist),
                      onDelete: () async {
                        if (!await _confirmDelete(context, playlist.name)) return;
                        final snapshot = await ref.read(playlistsProvider.notifier).delete(playlist.id);
                        if (!context.mounted || snapshot == null) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('“${snapshot.name}” deleted'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => ref.read(playlistsProvider.notifier).restore(snapshot),
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
    final playlist = ref.watch(playlistsProvider).where((p) => p.id == playlistId).firstOrNull;
    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/playlists'),
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
    final library = ref.watch(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[];
    final byId = {for (final item in library) item.id: item};
    final tracks = playlist.mediaIds.map((id) => byId[id]).whereType<MediaItem>().toList();
    final missingCount = playlist.mediaIds.length - tracks.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/playlists'),
        ),
        title: Text(playlist.name),
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
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 26),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _play(context, ref, tracks, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play all'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final shuffled = List<MediaItem>.from(tracks)..shuffle();
                          _play(context, ref, shuffled, 0);
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                      ),
                    ),
                  ],
                ),
                if (missingCount > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '$missingCount saved item${missingCount == 1 ? '' : 's'} could not be found on this device.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                ...List.generate(tracks.length, (index) {
                  final item = tracks[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.cardOf(context),
                      child: Icon(item.isVideo ? Icons.movie_rounded : Icons.music_note_rounded, color: AppColors.accent),
                    ),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.formattedDuration),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'remove') {
                          ref.read(playlistsProvider.notifier).removeTrack(playlist.id, item.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'remove', child: Text('Remove from playlist')),
                      ],
                    ),
                    onTap: () => _play(context, ref, tracks, index),
                  );
                }),
              ],
            ),
    );
  }
}

void _play(BuildContext context, WidgetRef ref, List<MediaItem> queue, int index) {
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No local media is available to add.')));
    return;
  }
  final existing = playlist.mediaIds.toSet();
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .82,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Add to playlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ),
          Expanded(
            child: StatefulBuilder(
              builder: (context, setSheetState) => ListView.builder(
                itemCount: library.length,
                itemBuilder: (context, index) {
                  final item = library[index];
                  final added = existing.contains(item.id);
                  return ListTile(
                    leading: Icon(item.isVideo ? Icons.movie_outlined : Icons.music_note_rounded),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.formattedDuration),
                    trailing: Icon(added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: added ? AppColors.accentGreen : AppColors.accent),
                    enabled: !added,
                    onTap: added
                        ? null
                        : () async {
                            await ref.read(playlistsProvider.notifier).addTrack(playlist.id, item);
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

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap, required this.onRename, required this.onDelete});
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          onTap: onTap,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.queue_music_rounded, color: AppColors.accent),
          ),
          title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${playlist.mediaIds.length} item${playlist.mediaIds.length == 1 ? '' : 's'}'),
          trailing: PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'rename') onRename();
              if (action == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
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
              const Icon(Icons.queue_music_rounded, size: 60, color: AppColors.accent),
              const SizedBox(height: 14),
              const Text('No playlists yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              const Text('Playlists stay on this device and work without an account.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('Create playlist')),
            ],
          ),
        ),
      );
}

class _EmptyPlaylistDetail extends StatelessWidget {
  const _EmptyPlaylistDetail({required this.missingCount, required this.onAdd});
  final int missingCount;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_add_rounded, size: 58, color: AppColors.accent),
              const SizedBox(height: 14),
              Text(missingCount > 0 ? 'Saved files are missing' : 'This playlist is empty', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(missingCount > 0 ? 'The playlist is intact, but its saved files are not currently available on this device.' : 'Add local songs or videos to begin.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add media')),
            ],
          ),
        ),
      );
}

Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
  final name = await _askName(context, title: 'New playlist', action: 'Create');
  if (name == null) return;
  await ref.read(playlistsProvider.notifier).create(name);
}

Future<void> _renamePlaylist(BuildContext context, WidgetRef ref, Playlist playlist) async {
  final name = await _askName(context, title: 'Rename playlist', action: 'Save', initial: playlist.name);
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
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
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
        content: Text('Delete “$name”? The media files themselves are not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    ) ?? false;
