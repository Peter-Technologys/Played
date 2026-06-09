import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_scanner_service.dart';

// ── Folder Browser ─────────────────────────────────────────────

final folderBrowserProvider =
    FutureProvider<Map<String, List<MediaItem>>>((ref) async {
  final items = await MediaScannerService.instance.scanAll();
  final Map<String, List<MediaItem>> folders = {};
  for (final item in items) {
    final parts = item.filePath.split('/');
    final folder = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('/')
        : '/';
    folders.putIfAbsent(folder, () => []).add(item);
  }
  return folders;
});

class FolderBrowserScreen extends ConsumerWidget {
  const FolderBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(folderBrowserProvider);

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
        title: const Text('Folder Browser',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 18,
            )),
      ),
      body: foldersAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: AppColors.error))),
        data: (folders) {
          final keys = folders.keys.toList()..sort();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final path = keys[i];
              final files = folders[path]!;
              final folderName = path.split('/').last;
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FolderDetailScreen(
                      folderName: folderName,
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
                                  fontFamily: 'SpaceGrotesk',
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
        },
      ),
    );
  }
}

class _FolderDetailScreen extends StatelessWidget {
  final String folderName;
  final List<MediaItem> items;
  const _FolderDetailScreen(
      {required this.folderName, required this.items});

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
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 16,
            )),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return ListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            leading: Icon(
              item.isVideo
                  ? Icons.videocam_rounded
                  : Icons.music_note_rounded,
              color: item.isVideo
                  ? AppColors.accent
                  : AppColors.accentViolet,
            ),
            title: Text(item.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'SpaceGrotesk',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${item.formattedDuration} · ${item.formattedSize}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            onTap: () {
              HapticFeedback.lightImpact();
            },
          );
        },
      ),
    );
  }
}
