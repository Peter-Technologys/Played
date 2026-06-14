import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/data/media_repository.dart';

class FolderBrowserScreen extends StatelessWidget {
  const FolderBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FolderBrowserBody();
  }
}

class _FolderBrowserBody extends StatefulWidget {
  const _FolderBrowserBody();

  @override
  State<_FolderBrowserBody> createState() => _FolderBrowserBodyState();
}

class _FolderBrowserBodyState extends State<_FolderBrowserBody> {
  Map<String, List<MediaItem>>? _folders;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = MediaRepository.instance.cachedItems ??
          await MediaRepository.instance.getAllMedia();
      final Map<String, List<MediaItem>> folders = {};
      for (final item in items) {
        final parts = item.filePath.split('/');
        final folder = parts.length > 1
            ? parts.sublist(0, parts.length - 1).join('/')
            : '/';
        folders.putIfAbsent(folder, () => []).add(item);
      }
      if (mounted) setState(() { _folders = folders; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Browse by Folder',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 18,
            )),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)))
              : _folders == null || _folders!.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_off_rounded,
                              color: AppColors.textSecondary, size: 48),
                          SizedBox(height: 12),
                          Text('No folders found',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15)),
                        ],
                      ),
                    )
                  : _FolderList(folders: _folders!),
    );
  }
}

class _FolderList extends StatelessWidget {
  final Map<String, List<MediaItem>> folders;
  const _FolderList({required this.folders});

  @override
  Widget build(BuildContext context) {
    final keys = folders.keys.toList()..sort();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final path = keys[i];
        final files = folders[path]!;
        final parts = path.split('/');
        final folderName = parts.last.isEmpty && parts.length > 1
            ? parts[parts.length - 2]
            : parts.last.isEmpty ? path : parts.last;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _FolderDetailScreen(
                folderName: folderName,
                fullPath: path,
                items: files,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_rounded,
                      color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(folderName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${files.length} file${files.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ).animate().fadeIn(
                duration: 300.ms,
                delay: Duration(milliseconds: i * 30),
              ),
        );
      },
    );
  }
}

class _FolderDetailScreen extends StatelessWidget {
  final String folderName;
  final String fullPath;
  final List<MediaItem> items;
  const _FolderDetailScreen({
    required this.folderName,
    required this.fullPath,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(folderName,
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
              child: Text(
                '${items.length} file${items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final route =
                  item.isVideo ? '/player/video' : '/player/audio';
              context.push(route, extra: item);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.isVideo
                          ? AppColors.accent.withValues(alpha: 0.1)
                          : AppColors.accentViolet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.isVideo
                          ? Icons.videocam_rounded
                          : Icons.music_note_rounded,
                      color: item.isVideo
                          ? AppColors.accent
                          : AppColors.accentViolet,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${item.formattedDuration} · ${item.formattedSize}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    item.isVideo
                        ? Icons.play_circle_outline_rounded
                        : Icons.headphones_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ).animate().fadeIn(
                  duration: 250.ms,
                  delay: Duration(milliseconds: i * 20),
                ),
          );
        },
      ),
    );
  }
}
