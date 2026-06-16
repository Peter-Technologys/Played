import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/database/played_database.dart';
import '../../../core/services/vault_service.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'providers/my_space_provider.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/user_avatar_button.dart';
import '../../player/presentation/queue_screen.dart';
import '../../playlists/playlist_screen.dart' show PlaylistsScreen, playlistsProvider;
import 'file_management_sheet.dart';

// ── Recently Played row ─────────────────────────────────────────────
class _RecentlyPlayedRow extends ConsumerWidget {
  const _RecentlyPlayedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = PlayedDatabase.instance.getRecentlyPlayed(limit: 20);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            'RECENTLY PLAYED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.3,
              fontFamily: 'Inter',
            ),
          ),
        ),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = recent[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(queueProvider.notifier)
                      .setQueue(recent, startIndex: i);
                  context.push(
                    item.isVideo ? '/player/video' : '/player/audio',
                    extra: item,
                  );
                },
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.isVideo
                              ? AppColors.accent.withValues(alpha: 0.12)
                              : AppColors.accentViolet.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item.isVideo
                              ? Icons.play_circle_rounded
                              : Icons.music_note_rounded,
                          color: item.isVideo
                              ? AppColors.accent
                              : AppColors.accentViolet,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.artist != null &&
                                      item.artist != '<unknown>'
                                  ? item.artist!
                                  : item.formattedDuration,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Sort ─────────────────────────────────────────────────────────────
enum MediaSort { dateAdded, name, size, duration }

final _sortProvider = StateProvider<MediaSort>((_) => MediaSort.dateAdded);

// ── Root screen ──────────────────────────────────────────────────────

class MySpaceScreen extends ConsumerStatefulWidget {
  const MySpaceScreen({super.key});

  @override
  ConsumerState<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends ConsumerState<MySpaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(mediaLibraryProvider);
    final sort = ref.watch(_sortProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _Header(
              libraryAsync: libraryAsync,
              sort: sort,
              onRefresh: () =>
                  ref.read(mediaLibraryProvider.notifier).refresh(),
            ),

            // ── Recently Played ──────────────────────────────────────
            const _RecentlyPlayedRow(),

            // ── Tab bar ─────────────────────────────────────────────
            _TabBar(controller: _tabs),

            // ── Tab views ───────────────────────────────────────────
            Expanded(
              child: libraryAsync.when(
                loading: () => const _FullShimmer(),
                error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(mediaLibraryProvider.notifier).refresh(),
                ),
                data: (items) => _TabViews(
                  controller: _tabs,
                  items: items,
                  sort: sort,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final AsyncValue<List<MediaItem>> libraryAsync;
  final MediaSort sort;
  final VoidCallback onRefresh;

  const _Header({
    required this.libraryAsync,
    required this.sort,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = libraryAsync.valueOrNull?.length ?? 0;
    final isRefreshing = libraryAsync.isLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Space',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              Text(
                total == 0 ? 'Scanning...' : '$total files',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          const UserAvatarButton(),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.search_rounded,
            onTap: () {
              final items = ref.read(mediaLibraryProvider).valueOrNull ?? [];
              showSearch(
                context: context,
                delegate: MediaSearchDelegate(allItems: items),
              );
            },
          ),
          const SizedBox(width: 8),
          _SortBtn(current: sort),
          const SizedBox(width: 8),
          _IconBtn(
            icon: isRefreshing ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            onTap: isRefreshing ? () {} : onRefresh,
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.settings_rounded,
            accent: true,
            onTap: () => context.push('/settings'),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

// ── Tab bar ──────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentViolet],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        tabs: const [
          Tab(text: 'Songs'),
          Tab(text: 'Videos'),
          Tab(text: 'Folders'),
          Tab(text: 'Playlists'),
        ],
      ),
    );
  }
}

// ── Tab views ────────────────────────────────────────────────────────

class _TabViews extends StatelessWidget {
  final TabController controller;
  final List<MediaItem> items;
  final MediaSort sort;

  const _TabViews({
    required this.controller,
    required this.items,
    required this.sort,
  });

  List<MediaItem> _sorted(List<MediaItem> src) {
    final list = List.of(src);
    switch (sort) {
      case MediaSort.name:
        list.sort((a, b) => a.title.compareTo(b.title));
      case MediaSort.size:
        list.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
      case MediaSort.duration:
        list.sort((a, b) => (b.duration ?? Duration.zero)
            .compareTo(a.duration ?? Duration.zero));
      case MediaSort.dateAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final songs = _sorted(items.where((e) => !e.isVideo).toList());
    final videos = _sorted(items.where((e) => e.isVideo).toList());

    return TabBarView(
      controller: controller,
      children: [
        // Songs
        items.isEmpty
            ? const _EmptyState(icon: Icons.music_note_rounded, label: 'No songs found')
            : _SongList(items: songs),

        // Videos
        items.isEmpty
            ? const _EmptyState(icon: Icons.videocam_rounded, label: 'No videos found')
            : _VideoGrid(items: videos),

        // Folders
        _FoldersTab(items: items),

        // Playlists
        const _PlaylistsTab(),
      ],
    );
  }
}

// ── Songs tab — flat list like PlayIt ────────────────────────────────

class _SongList extends ConsumerWidget {
  final List<MediaItem> items;
  const _SongList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _EmptyState(
          icon: Icons.music_note_rounded, label: 'No songs found');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return _SongRow(
          item: item,
          index: i,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(queueProvider.notifier).setQueue(items, startIndex: i);
            context.push('/player/audio', extra: item);
          },
        );
      },
    );
  }
}

class _SongRow extends ConsumerWidget {
  final MediaItem item;
  final int index;
  final VoidCallback onTap;
  const _SongRow({required this.item, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentViolet, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.artist != null &&
                            item.artist!.isNotEmpty &&
                            item.artist != '<unknown>'
                        ? item.artist!
                        : item.formattedDuration,
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
            Text(
              item.formattedDuration,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showContextMenu(context, ref),
              child: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SongContextMenu(item: item, ref: ref),
    );
  }
}

class _SongContextMenu extends ConsumerWidget {
  final MediaItem item;
  final WidgetRef ref;
  const _SongContextMenu({required this.item, required this.ref});

  // Shows a bottom sheet to pick which playlist to add the song to.
  void _showPlaylistPicker(BuildContext context, WidgetRef r) {
    final playlists = PlayedDatabase.instance.getAllPlaylists();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Add to Playlist',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    final ctrl = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('New Playlist',
                            style: TextStyle(color: AppColors.textPrimary)),
                        content: TextField(
                          controller: ctrl,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Playlist name',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.border)),
                            focusedBorder: UnderlineInputBorder(
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
                            onPressed: () => Navigator.pop(context, ctrl.text),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent),
                            child: const Text('Create',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (name != null && name.trim().isNotEmpty && context.mounted) {
                      final pl = await r.read(playlistsProvider.notifier).create(name.trim());
                      await r.read(playlistsProvider.notifier).addTrack(pl.id, item);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "${pl.name}"'),
                            backgroundColor: AppColors.surface,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Text('+ New',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No playlists yet. Tap + New to create one.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
              )
            else
              ...playlists.map((pl) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentViolet]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.queue_music_rounded,
                          color: Colors.black, size: 20),
                    ),
                    title: Text(pl.name,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                    subtitle: Text(
                      '${pl.mediaIds.length} track${pl.mediaIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await r.read(playlistsProvider.notifier).addTrack(pl.id, item);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "${pl.name}"'),
                            backgroundColor: AppColors.surface,
                          ),
                        );
                      }
                    },
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef r) {
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
                borderRadius: BorderRadius.circular(2),
              ),
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
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        item.artist != null && item.artist != '<unknown>'
                            ? item.artist!
                            : item.formattedDuration,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _ContextOption(
            icon: Icons.play_arrow_rounded,
            label: 'Play',
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              r.read(queueProvider.notifier).setQueue([item]);
              context.push('/player/audio', extra: item);
            },
          ),
          _ContextOption(
            icon: Icons.queue_music_rounded,
            label: 'Add to Queue',
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              r.read(queueProvider.notifier).addToQueue(item);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to queue')),
              );
            },
          ),
          _ContextOption(
            icon: Icons.playlist_add_rounded,
            label: 'Add to Playlist',
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              _showPlaylistPicker(context, r);
            },
          ),
          _ContextOption(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppColors.textSecondary,
            onTap: () async {
              Navigator.pop(context);
              await Share.shareXFiles(
                [XFile(item.filePath)],
                text: item.title,
              );
            },
          ),
          _ContextOption(
            icon: Icons.lock_rounded,
            label: 'Move to Vault',
            color: AppColors.accentViolet,
            onTap: () async {
              Navigator.pop(context);
              try {
                await VaultService.instance.lockItem(item);
                r.read(mediaLibraryProvider.notifier).refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Moved to Vault ✔'),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Vault error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
          _ContextOption(
            icon: Icons.drive_file_rename_outline_rounded,
            label: 'Rename / Delete',
            color: AppColors.textSecondary,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.surface,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => FileManagementSheet(item: item),
              );
            },
          ),
          _ContextOption(
            icon: Icons.info_outline_rounded,
            label: 'File Info',
            color: AppColors.textSecondary,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.surface,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => _FileInfoSheet(item: item),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContextOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContextOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
    );
  }
}

class _FileInfoSheet extends StatelessWidget {
  final MediaItem item;
  const _FileInfoSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Title', item.title),
      ('Artist', item.artist ?? 'Unknown'),
      ('Album', item.album ?? 'Unknown'),
      ('Duration', item.formattedDuration),
      ('Size', item.formattedSize),
      ('Path', item.filePath),
      ('Added', item.addedAt.toLocal().toString().split('.').first),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('File Info',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(r.$1,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(r.$2,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Videos tab — grid like PlayIt ────────────────────────────────────

class _VideoGrid extends ConsumerWidget {
  final List<MediaItem> items;
  const _VideoGrid({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _EmptyState(
          icon: Icons.videocam_rounded, label: 'No videos found');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 11,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return _VideoCard(
          item: item,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(queueProvider.notifier).setQueue(items, startIndex: i);
            context.push('/player/video', extra: item);
          },
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _VideoCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent, AppColors.accentViolet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.formattedDuration,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Folders tab ──────────────────────────────────────────────────────

class _FoldersTab extends StatelessWidget {
  final List<MediaItem> items;
  const _FoldersTab({required this.items});

  Map<String, List<MediaItem>> _buildFolders() {
    final map = <String, List<MediaItem>>{};
    for (final item in items) {
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
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
          icon: Icons.folder_open_rounded, label: 'No folders found');
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
        final audioCount = files.where((f) => !f.isVideo).length;
        final videoCount = files.where((f) => f.isVideo).length;

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
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder_rounded,
                  color: AppColors.accent, size: 24),
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
              [
                if (audioCount > 0) '$audioCount song${audioCount == 1 ? '' : 's'}',
                if (videoCount > 0) '$videoCount video${videoCount == 1 ? '' : 's'}',
              ].join(' · '),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () => _openFolder(context, name, files),
          ),
        );
      },
    );
  }

  void _openFolder(
      BuildContext context, String name, List<MediaItem> files) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FolderDetailPage(name: name, items: files),
    ));
  }
}

class _FolderDetailPage extends ConsumerWidget {
  final String name;
  final List<MediaItem> items;
  const _FolderDetailPage({required this.name, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 16,
            )),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${items.length} files',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
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
              ref.read(queueProvider.notifier).setQueue(items, startIndex: i);
              final route = item.isVideo ? '/player/video' : '/player/audio';
              context.push(route, extra: item);
            },
          );
        },
      ),
    );
  }
}

// ── Playlists tab ────────────────────────────────────────────────────

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch playlistsProvider so this tab rebuilds reactively whenever
    // playlists are created, renamed, or deleted.
    final playlists = ref.watch(playlistsProvider);
    if (playlists.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _EmptyState(
              icon: Icons.queue_music_rounded, label: 'No playlists yet'),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/playlists'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Create Playlist',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: playlists.length,
      itemBuilder: (context, i) {
        final pl = playlists[i];
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
              child: const Icon(Icons.queue_music_rounded,
                  color: AppColors.accentViolet, size: 22),
            ),
            title: Text(
              pl.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            subtitle: Text(
              '${pl.mediaIds.length} track${pl.mediaIds.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () => context.push('/playlists'),
          ),
        );
      },
    );
  }
}

// ── Sort button ──────────────────────────────────────────────────────

class _SortBtn extends ConsumerWidget {
  final MediaSort current;
  const _SortBtn({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _IconBtn(
      icon: Icons.sort_rounded,
      accent: current != MediaSort.dateAdded,
      onTap: () => _showSheet(context, ref),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sort by',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 16),
            ...MediaSort.values.map((s) {
              final label = switch (s) {
                MediaSort.dateAdded => 'Date Added',
                MediaSort.name => 'Name (A \u2192 Z)',
                MediaSort.size => 'File Size',
                MediaSort.duration => 'Duration',
              };
              final isActive = current == s;
              return ListTile(
                title: Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      color: isActive
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                    )),
                trailing: isActive
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.accent, size: 18)
                    : null,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  ref.read(_sortProvider.notifier).state = s;
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ───────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  const _IconBtn(
      {required this.icon, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: accent ? AppColors.accent : AppColors.border),
        ),
        child: Icon(icon,
            color: accent ? AppColors.accent : AppColors.textSecondary,
            size: 18),
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
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Files will appear here after scanning.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FullShimmer extends StatelessWidget {
  const _FullShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          const MediaGridShimmer(count: 6),
          const SizedBox(height: 16),
          const MediaGridShimmer(count: 4),
        ],
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
            const Text('Could not load media',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Try Again',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
