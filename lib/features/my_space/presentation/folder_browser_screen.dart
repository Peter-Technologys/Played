import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import '../../player/presentation/mini_player.dart';
import '../../player/presentation/queue_screen.dart';
import '../../search/smart_search_sheet.dart';

class FolderBrowserScreen extends ConsumerWidget {
  const FolderBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(mediaLibraryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/myspace'),
        ),
        title: const Text('Files'),
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
              : _FilesBody(items: cached);
        },
        error: (_, __) => _FilesError(
          onRetry: () => ref.read(mediaLibraryProvider.notifier).refresh(),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.read(mediaLibraryProvider.notifier).refresh(),
          child: _FilesBody(items: items),
        ),
      ),
    );
  }
}

class _FilesBody extends StatelessWidget {
  const _FilesBody({required this.items});
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final folders = <String, List<MediaItem>>{};
    for (final item in items) {
      final normalized = item.filePath.replaceAll('\\', '/');
      final lastSlash = normalized.lastIndexOf('/');
      final path = lastSlash > 0 ? normalized.substring(0, lastSlash) : '/';
      folders.putIfAbsent(path, () => <MediaItem>[]).add(item);
    }
    final entries = folders.entries.toList()
      ..sort((a, b) => _folderName(a.key).toLowerCase().compareTo(_folderName(b.key).toLowerCase()));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_copy_rounded, color: AppColors.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${items.length} playable file${items.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${entries.length} media folder${entries.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/downloads'),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Downloads'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Column(
              children: [
                Icon(Icons.folder_off_outlined, size: 54, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text('No playable media folders found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('OTYA Files currently shows folders containing audio or video indexed by Android MediaStore.', textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ...entries.map((entry) {
            final name = _folderName(entry.key);
            final videoCount = entry.value.where((item) => item.isVideo).length;
            final audioCount = entry.value.length - videoCount;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.folder_rounded, color: AppColors.accent),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text([
                  if (videoCount > 0) '$videoCount video',
                  if (audioCount > 0) '$audioCount audio',
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/tools/folder-detail', extra: {
                  'folderName': name,
                  'fullPath': entry.key,
                  'items': entry.value,
                }),
              ),
            );
          }),
      ],
    );
  }

  static String _folderName(String path) {
    final parts = path.replaceAll('\\', '/').split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? 'Device' : parts.last;
  }
}

class FolderDetailScreen extends ConsumerWidget {
  const FolderDetailScreen({
    super.key,
    required this.folderName,
    required this.fullPath,
    required this.items,
  });

  final String folderName;
  final String fullPath;
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = List<MediaItem>.from(items)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/tools/folders'),
        ),
        title: Text(folderName),
      ),
      body: queue.isEmpty
          ? const Center(child: Text('This folder has no playable media.'))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.paddingOf(context).bottom + 24),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.cardOf(context),
                    child: Icon(item.isVideo ? Icons.movie_rounded : Icons.music_note_rounded, color: AppColors.accent),
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${item.formattedDuration} · ${item.formattedSize}'),
                  trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.accent),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(queueProvider.notifier).setQueue(queue, startIndex: index);
                    if (item.isVideo) {
                      context.push('/player/video', extra: item);
                    } else {
                      ref.read(miniPlayerItemProvider.notifier).state = item;
                      context.push('/player/audio', extra: item);
                    }
                  },
                );
              },
            ),
    );
  }
}

class _FilesError extends StatelessWidget {
  const _FilesError({required this.onRetry});
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
              const Text('OTYA could not read the local media folders.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      );
}
