import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../core/database/played_database.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playlist.dart';
import '../../features/my_space/data/media_repository.dart';
import '../../features/my_space/presentation/providers/my_space_provider.dart';
import '../../features/player/presentation/audio_player_screen.dart';
import '../../features/player/presentation/mini_player.dart';
import '../../features/player/presentation/queue_screen.dart';

// ── Provider ───────────────────────────────────────────────────

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<Playlist>>(
  (ref) => PlaylistsNotifier()..load(),
);

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier() : super([]);

  void load() {
    state = PlayedDatabase.instance.getAllPlaylists();
  }

  Future<Playlist> create(String name) async {
    const uuid = Uuid();
    final playlist = Playlist(
      id: uuid.v4(),
      name: name,
      mediaIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await PlayedDatabase.instance.savePlaylist(playlist);
    state = [...state, playlist];
    return playlist;
  }

  Future<void> rename(String id, String newName) async {
    final playlist = PlayedDatabase.instance.getPlaylist(id);
    if (playlist == null) return;
    final updated = Playlist(
      id: playlist.id,
      name: newName,
      mediaIds: playlist.mediaIds,
      createdAt: playlist.createdAt,
      updatedAt: DateTime.now(),
    );
    await PlayedDatabase.instance.savePlaylist(updated);
    state = state.map((p) => p.id == id ? updated : p).toList();
  }

  Future<void> delete(String id) async {
    await PlayedDatabase.instance.deletePlaylist(id);
    state = state.where((p) => p.id != id).toList();
  }

  Future<void> addTrack(String playlistId, MediaItem item) async {
    await PlayedDatabase.instance.addToPlaylist(playlistId, item);
    load();
  }

  Future<void> removeTrack(String playlistId, String mediaId) async {
    final playlist = PlayedDatabase.instance.getPlaylist(playlistId);
    if (playlist == null) return;
    playlist.mediaIds.remove(mediaId);
    await PlayedDatabase.instance.savePlaylist(playlist);
    load();
  }
}

// ── Playlists Screen ───────────────────────────────────────────

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Playlists',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
            )),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.accent),
            onPressed: () => _showCreateDialog(context, ref),
            tooltip: 'New playlist',
          ),
        ],
      ),
      body: playlists.isEmpty
          ? _EmptyState(onCreate: () => _showCreateDialog(context, ref))
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16,
                  MediaQuery.of(context).padding.bottom + 90),
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final pl = playlists[i];
                return Dismissible(
                  key: ValueKey(pl.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text('Delete "${pl.name}"?',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'Inter')),
                        content: const Text(
                          'This will remove the playlist but not the files.',
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color: AppColors.textSecondary)),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ) ??
                        false;
                  },
                  onDismissed: (_) async {
                    final deletedName = pl.name;
                    final deletedId = pl.id;
                    await ref
                        .read(playlistsProvider.notifier)
                        .delete(deletedId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('"$deletedName" deleted'),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () async {
                              await ref
                                  .read(playlistsProvider.notifier)
                                  .create(deletedName);
                            },
                          ),
                        ),
                      );
                    }
                  },
                  child: _PlaylistTile(
                    playlist: pl,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/playlist/${pl.id}');
                    },
                    onRename: () => _showRenameDialog(context, ref, pl),
                    onDelete: () => _confirmDelete(context, ref, pl),
                  ).animate().fadeIn(duration: 300.ms,
                      delay: Duration(milliseconds: i * 40)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Playlist',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(
          controller: controller, title: 'New Playlist', hint: 'Playlist name'),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(playlistsProvider.notifier).create(name.trim());
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, Playlist pl) async {
    final controller = TextEditingController(text: pl.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(
          controller: controller, title: 'Rename Playlist', hint: pl.name),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(playlistsProvider.notifier).rename(pl.id, name.trim());
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Playlist pl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${pl.name}"?',
            style: const TextStyle(
                color: AppColors.textPrimary, fontFamily: 'Inter')),
        content: const Text('This will remove the playlist but not the files.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(playlistsProvider.notifier).delete(pl.id);
    }
  }
}

// ── Playlist Tile ──────────────────────────────────────────────

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.queue_music_rounded,
                  color: Colors.black, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name,
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    '${playlist.mediaIds.length} track${playlist.mediaIds.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: AppColors.surface,
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary, size: 20),
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded,
                          color: AppColors.accent, size: 18),
                      SizedBox(width: 10),
                      Text('Rename',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded,
                          color: AppColors.error, size: 18),
                      SizedBox(width: 10),
                      Text('Delete',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Playlist Detail Screen (by ID — for GoRouter) ─────────────

/// GoRouter-compatible wrapper: looks up the playlist by [playlistId] from
/// [playlistsProvider] and delegates to [PlaylistDetailScreen].
class PlaylistDetailScreenById extends ConsumerWidget {
  final String playlistId;
  const PlaylistDetailScreenById({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
    if (playlist == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('Playlist not found',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return PlaylistDetailScreen(playlist: playlist);
  }
}

// ── Playlist Detail Screen ─────────────────────────────────────

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  void _showAddSongsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddSongsSheet(playlist: widget.playlist),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Resolve MediaItems from IDs — watch the live provider so cold-start
    // and post-scan updates are reflected immediately.
    final libraryItems = ref.watch(mediaLibraryProvider).valueOrNull
        ?? MediaRepository.instance.cachedItems
        ?? [];
    final tracks = widget.playlist.mediaIds
        .map((id) { try { return libraryItems.firstWhere((m) => m.id == id); } catch (_) { return null; } })
        .whereType<MediaItem>()
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.playlist.name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
            )),
        actions: [
          if (tracks.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.shuffle_rounded,
                  color: AppColors.textSecondary, size: 22),
              tooltip: 'Shuffle play',
              onPressed: () {
                HapticFeedback.mediumImpact();
                final shuffled = List.of(tracks)..shuffle();
                ref.read(queueProvider.notifier).setQueue(shuffled);
                ref.read(miniPlayerItemProvider.notifier).state = shuffled.first;
                context.push('/player/audio', extra: shuffled.first);
              },
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.accent, size: 28),
              tooltip: 'Play all',
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(queueProvider.notifier).setQueue(tracks);
                ref.read(miniPlayerItemProvider.notifier).state = tracks.first;
                context.push('/player/audio', extra: tracks.first);
              },
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSongsSheet,
        backgroundColor: AppColors.accentViolet,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Songs',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: tracks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_off_rounded,
                      color: AppColors.textSecondary, size: 48),
                  const SizedBox(height: 12),
                  const Text('No tracks yet',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                          fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text(
                    'Long-press any file in My Space\nto add it to this playlist.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tracks.length,
              onReorder: (oldIndex, newIndex) {
                // ReorderableListView passes newIndex after removal;
                // adjust when moving downward.
                final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
                final ids = List<String>.from(widget.playlist.mediaIds);
                final id = ids.removeAt(oldIndex);
                ids.insert(adjusted, id);
                final updated = Playlist(
                  id: widget.playlist.id,
                  name: widget.playlist.name,
                  mediaIds: ids,
                  createdAt: widget.playlist.createdAt,
                  updatedAt: DateTime.now(),
                );
                PlayedDatabase.instance.savePlaylist(updated);
                ref.read(playlistsProvider.notifier).load();
              },
              itemBuilder: (context, i) {
                final item = tracks[i];
                return ListTile(
                  key: ValueKey(item.id),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.isVideo
                          ? Icons.videocam_rounded
                          : Icons.music_note_rounded,
                      color: item.isVideo
                          ? AppColors.accent
                          : AppColors.accentViolet,
                      size: 20,
                    ),
                  ),
                  title: Text(item.title,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    item.artist ?? item.formattedDuration,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(playlistsProvider.notifier)
                              .removeTrack(widget.playlist.id, item.id);
                        },
                        child: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.drag_handle_rounded,
                          color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(queueProvider.notifier).setQueue(tracks, startIndex: i);
                    ref.read(miniPlayerItemProvider.notifier).state = item;
                    context.push('/player/audio', extra: item);
                  },
                );
              },
            ),
    );
  }
}

// ── Add Songs Sheet ────────────────────────────────────────────

class _AddSongsSheet extends ConsumerStatefulWidget {
  final Playlist playlist;
  const _AddSongsSheet({required this.playlist});

  @override
  ConsumerState<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends ConsumerState<_AddSongsSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMedia = MediaRepository.instance.cachedItems ?? [];
    final audioTracks = allMedia.where((item) => !item.isVideo).toList();
    final filtered = _query.isEmpty
        ? audioTracks
        : audioTracks.where((item) {
            final q = _query.toLowerCase();
            return item.title.toLowerCase().contains(q) ||
                (item.artist?.toLowerCase().contains(q) ?? false);
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Add Songs to ${widget.playlist.name}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search songs…',
                hintStyle:
                    const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 20),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          // Track list
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No songs found',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accentViolet
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.music_note_rounded,
                              color: AppColors.accentViolet, size: 20),
                        ),
                        title: Text(item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          item.artist ?? item.formattedDuration,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                        onTap: () async {
                          await ref
                              .read(playlistsProvider.notifier)
                              .addTrack(widget.playlist.id, item);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '"${item.title}" added to playlist'),
                                backgroundColor: AppColors.surface,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Name Dialog ────────────────────────────────────────────────

class _NameDialog extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;
  const _NameDialog(
      {required this.controller, required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter')),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: AppColors.textSecondary),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent)),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent),
          child: const Text('Save',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Empty State ────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.queue_music_rounded,
                color: AppColors.textSecondary, size: 36),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.08,
                  duration: 1000.ms, curve: Curves.easeInOut),
          const SizedBox(height: 20),
          Text('No playlists yet',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              )).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          const Text(
            'Tap + to create your first playlist.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Create Playlist',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.black, fontFamily: 'Inter',
                  )),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        ],
      ),
    );
  }
}
