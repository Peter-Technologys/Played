import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../../player/presentation/queue_screen.dart';
import '../../my_space/presentation/playback_history_screen.dart';
import '../../../features/playlists/playlist_screen.dart' show playlistsProvider;

// ── Filter pill state ─────────────────────────────────────────────────────

enum _VideoFilter { videos, folders, playlists }

final _videoFilterProvider =
    StateProvider<_VideoFilter>((_) => _VideoFilter.videos);

// ── Video Tab Screen ──────────────────────────────────────────────────────

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
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final libraryAsync = ref.watch(mediaLibraryProvider);
    final filter = ref.watch(_videoFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _VideoHeader(libraryAsync: libraryAsync),

            // ── Filter pills ─────────────────────────────────────────
            _FilterPills(current: filter),

            // ── Content ──────────────────────────────────────────────
            Expanded(
              child: libraryAsync.when(
                loading: () => libraryAsync.valueOrNull != null
                    ? _buildContent(
                        context, libraryAsync.valueOrNull!, filter)
                    : const _VideoShimmer(),
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
      BuildContext context, List<MediaItem> items, _VideoFilter filter) {
    final videos = items.where((e) => e.isVideo).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    switch (filter) {
      case _VideoFilter.videos:
        return _VideoGrid(items: videos);
      case _VideoFilter.folders:
        return _VideoFoldersTab(items: videos);
      case _VideoFilter.playlists:
        return const _PlaylistsView();
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _VideoHeader extends ConsumerWidget {
  final AsyncValue<List<MediaItem>> libraryAsync;
  const _VideoHeader({required this.libraryAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = libraryAsync.valueOrNull?.where((e) => e.isVideo).toList();
    final count = videos?.length ?? 0;
    final isScanning =
        libraryAsync.isLoading && libraryAsync.valueOrNull != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icons/play_store_512.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.accent,
                size: 34,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentViolet],
                  ).createShader(b),
                  child: const Text(
                    'Video Library',
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
                        '$count video${count == 1 ? '' : 's'}',
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
                          color: AppColors.accent,
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
              final videos = items.where((e) => e.isVideo).toList();
              showSearch(
                context: context,
                delegate: _VideoSearchDelegate(videos: videos, ref: ref),
              );
            },
          ),
          const SizedBox(width: 6),
          // History
          _IconBtn(
            icon: Icons.history_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PlaybackHistoryScreen()),
            ),
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
  final _VideoFilter current;
  const _FilterPills({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const pills = [
      (_VideoFilter.videos, 'Videos', Icons.play_circle_rounded),
      (_VideoFilter.folders, 'Folders', Icons.folder_rounded),
      (_VideoFilter.playlists, 'Playlists', Icons.queue_play_next_rounded),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: pills.map((pill) {
          final (filter, label, icon) = pill;
          final isActive = current == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(_videoFilterProvider.notifier).state = filter;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentViolet],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isActive
                          ? Colors.black
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.black
                            : AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Video Grid ────────────────────────────────────────────────────────────

class _VideoGrid extends ConsumerWidget {
  final List<MediaItem> items;
  const _VideoGrid({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const _EmptyState(
          icon: Icons.videocam_rounded, label: 'No videos found');
    }
    return Column(
      children: [
        // ── Shuffle all bar ──────────────────────────────────────────
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            final shuffled = List<MediaItem>.from(items)..shuffle();
            ref.read(queueProvider.notifier).setQueue(shuffled, startIndex: 0);
            context.push('/player/video', extra: shuffled.first);
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.shuffle_rounded,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Shuffle all (${items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                const Spacer(),
                const Icon(Icons.play_arrow_rounded,
                    color: AppColors.accent, size: 20),
              ],
            ),
          ),
        ),

        // ── Grid ─────────────────────────────────────────────────────
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 16 / 13,
            ),
            cacheExtent: 400,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return _VideoCard(
                item: item,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(queueProvider.notifier)
                      .setQueue(items, startIndex: i);
                  context.push('/player/video', extra: item);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Video Card ────────────────────────────────────────────────────────────

class _VideoCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _VideoCard({required this.item, required this.onTap});

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  static const _channel = MethodChannel('com.otyaplayer.app/media_store');
  String? _thumbPath;
  bool _disposed = false;

  // Session-level thumbnail cache shared across all instances
  static final Map<String, String?> _thumbCache = {};

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadThumb() async {
    final key = widget.item.id;
    if (_thumbCache.containsKey(key)) {
      final cached = _thumbCache[key];
      if (!_disposed && mounted && cached != null) {
        setState(() => _thumbPath = cached);
      }
      return;
    }
    try {
      final path = await _channel.invokeMethod<String>('getVideoThumbnail', {
        'path': widget.item.filePath,
        'id': widget.item.id,
      });
      _thumbCache[key] = path;
      if (!_disposed && mounted && path != null) {
        setState(() => _thumbPath = path);
      }
    } catch (_) {
      _thumbCache[key] = null;
    }
  }

  /// Infer a resolution badge from the file path.
  String _resolutionBadge() {
    final p = widget.item.filePath.toLowerCase();
    if (p.contains('1080')) return '1080p';
    if (p.contains('720')) return '720p';
    if (p.contains('480')) return '480p';
    if (p.contains('4k') || p.contains('2160')) return '4K';
    return '720p'; // sensible default
  }

  /// Extract the immediate parent folder name from the file path.
  String _folderName() {
    final parts = widget.item.filePath.split('/');
    if (parts.length >= 2) return parts[parts.length - 2];
    return 'Local';
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VideoContextMenu(
        item: widget.item,
        onPlay: widget.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail or gradient placeholder
                    _thumbPath != null
                        ? Image.file(
                            File(_thumbPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _gradientBg(),
                          )
                        : _gradientBg(),

                    // Play button overlay
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),

                    // Duration badge (bottom-right)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.formattedDuration,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),

                    // 3-dot menu (top-right)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showContextMenu(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Info area
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Resolution badge
                      _Badge(
                          label: _resolutionBadge(),
                          color: AppColors.accent),
                      const SizedBox(width: 4),
                      // File size
                      _Badge(
                          label: widget.item.formattedSize,
                          color: AppColors.textSecondary),
                      const Spacer(),
                      // Folder name
                      Flexible(
                        child: Text(
                          _folderName(),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1a1a2e), AppColors.accentViolet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(Icons.movie_rounded, color: Colors.white38, size: 32),
    ),
  );
}

// ── Small badge widget ────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ── Video context menu ────────────────────────────────────────────────────

class _VideoContextMenu extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onPlay;
  const _VideoContextMenu({required this.item, required this.onPlay});

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
              width: 40,
              height: 4,
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.movie_rounded,
                      color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(item.formattedDuration,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
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
              onPlay();
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
            label: 'Add to Vault',
            color: AppColors.accentViolet,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vault feature coming soon'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
          _ContextOption(
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
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter')),
      onTap: onTap,
      dense: true,
    );
  }
}

// ── Video Folders Tab ─────────────────────────────────────────────────────

class _VideoFoldersTab extends StatelessWidget {
  final List<MediaItem> items;
  const _VideoFoldersTab({required this.items});

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
          icon: Icons.folder_open_rounded, label: 'No video folders found');
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
              '${files.length} video${files.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _VideoFolderDetailPage(name: name, items: files),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoFolderDetailPage extends ConsumerWidget {
  final String name;
  final List<MediaItem> items;
  const _VideoFolderDetailPage(
      {required this.name, required this.items});

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
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${items.length} video${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 16 / 13,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return _VideoCard(
            item: item,
            onTap: () {
              HapticFeedback.lightImpact();
              ref
                  .read(queueProvider.notifier)
                  .setQueue(items, startIndex: i);
              context.push('/player/video', extra: item);
            },
          );
        },
      ),
    );
  }
}

// ── Playlists view ────────────────────────────────────────────────────────

class _PlaylistsView extends ConsumerWidget {
  const _PlaylistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    if (playlists.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _EmptyState(
            icon: Icons.queue_music_rounded,
            label: 'No playlists yet',
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/playlists');
            },
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
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/playlists');
            },
          ),
        );
      },
    );
  }
}

// ── Search delegate ───────────────────────────────────────────────────────

class _VideoSearchDelegate extends SearchDelegate<MediaItem?> {
  final List<MediaItem> videos;
  final WidgetRef ref;
  _VideoSearchDelegate({required this.videos, required this.ref});

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
        ? videos
        : videos
            .where((v) =>
                v.title.toLowerCase().contains(q) ||
                (v.artist?.toLowerCase().contains(q) ?? false))
            .toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No videos found',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Container(
      color: AppColors.background,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 16 / 13,
        ),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final item = results[i];
          return _VideoCard(
            item: item,
            onTap: () {
              ref
                  .read(queueProvider.notifier)
                  .setQueue(results, startIndex: i);
              close(context, item);
              context.push('/player/video', extra: item);
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
              color: AppColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 36),
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
            'Videos will appear here after scanning.',
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

class _VideoShimmer extends StatelessWidget {
  const _VideoShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: const Color(0xFF2A2F45),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 16 / 11,
        ),
        itemCount: 8,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
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
              'Could not load videos',
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
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.black,
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
