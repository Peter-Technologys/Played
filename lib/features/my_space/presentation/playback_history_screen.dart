import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/models/media_item.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../../player/presentation/queue_screen.dart';

class PlaybackHistoryScreen extends ConsumerStatefulWidget {
  const PlaybackHistoryScreen({super.key});

  @override
  ConsumerState<PlaybackHistoryScreen> createState() =>
      _PlaybackHistoryScreenState();
}

class _PlaybackHistoryScreenState
    extends ConsumerState<PlaybackHistoryScreen> {
  List<MediaItem> _history = [];

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so DB is guaranteed ready and setState is safe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _load() {
    try {
      final items = OtyaDatabase.instance.getPlaybackHistory(limit: 200);
      if (mounted) setState(() => _history = items);
    } catch (_) {
      if (mounted) setState(() => _history = []);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear History',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Remove all playback history? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await OtyaDatabase.instance.clearPlaybackHistory();
      } catch (_) {}
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playback history cleared'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WallpaperScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('History',
            style: TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontSize: 18,
            )),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: AppColors.textSecondary),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _history.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      color: AppColors.textSecondary, size: 64),
                  SizedBox(height: 16),
                  Text('No playback history yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Play a song or video to see it here.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(0, 8, 0,
                  MediaQuery.of(context).padding.bottom + 120),
              physics: const BouncingScrollPhysics(),
              itemCount: _history.length,
              itemBuilder: (context, i) {
                final item = _history[i];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: item.isVideo
                          ? AppColors.brandBlue.withValues(alpha: 0.12)
                          : AppColors.brandCyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.isVideo
                          ? Icons.videocam_rounded
                          : Icons.music_note_rounded,
                      color: item.isVideo
                          ? AppColors.brandBlue
                          : AppColors.brandCyan,
                      size: 20,
                    ),
                  ),
                  title: Text(item.title,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary, fontFamily: 'Inter',
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    item.lastPlayedAt != null
                        ? _formatTimestamp(item.lastPlayedAt!)
                        : item.formattedDuration,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.play_arrow_rounded,
                      color: AppColors.brandCyan, size: 20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref
                        .read(queueProvider.notifier)
                        .setQueue(_history, startIndex: i);
                    context.push(
                      item.isVideo ? '/player/video' : '/player/audio',
                      extra: item,
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    try {
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
