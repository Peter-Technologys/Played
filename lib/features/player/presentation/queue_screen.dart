import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/smart_shuffle_service.dart';

// ── Queue Provider ───────────────────────────────────────────────────

class QueueState {
  final List<MediaItem> items;
  final int currentIndex;
  final bool shuffle;
  const QueueState({
    this.items = const [],
    this.currentIndex = 0,
    this.shuffle = false,
  });
  QueueState copyWith({
    List<MediaItem>? items,
    int? currentIndex,
    bool? shuffle,
  }) =>
      QueueState(
        items: items ?? this.items,
        currentIndex: currentIndex ?? this.currentIndex,
        shuffle: shuffle ?? this.shuffle,
      );
  MediaItem? get current =>
      items.isEmpty ? null : items[currentIndex.clamp(0, items.length - 1)];
}

class QueueNotifier extends StateNotifier<QueueState> {
  QueueNotifier() : super(const QueueState());

  void setQueue(List<MediaItem> items, {int startIndex = 0}) {
    state = state.copyWith(items: items, currentIndex: startIndex);
  }

  void addToQueue(MediaItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeAt(int index) {
    final updated = List<MediaItem>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void reorder(int oldIndex, int newIndex) {
    final updated = List<MediaItem>.from(state.items);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = state.copyWith(items: updated);
  }

  void next() {
    if (state.items.isEmpty) return;
    final int nextIndex;
    if (state.shuffle) {
      // Build stats from recently played history for weighted shuffle.
      final history = OtyaDatabase.instance.getRecentlyPlayed(limit: 9999);
      final statsMap = <String, TrackStats>{
        for (final item in history)
          item.id: TrackStats(
            playCount:    1,
            lastPlayedMs: item.lastPlayedAt?.millisecondsSinceEpoch ?? 0,
            rating:       0,
            skipCount:    0,
          ),
      };
      final ids = state.items.map((i) => i.id).toList();
      final shuffled = SmartShuffleService.instance.smartShuffle(ids, statsMap);
      // Find the first shuffled ID that is not the current track.
      final currentId = state.items[state.currentIndex].id;
      final nextId = shuffled.firstWhere(
        (id) => id != currentId,
        orElse: () => shuffled.first,
      );
      nextIndex = state.items.indexWhere((item) => item.id == nextId);
    } else {
      nextIndex = (state.currentIndex + 1) % state.items.length;
    }
    state = state.copyWith(currentIndex: nextIndex < 0 ? 0 : nextIndex);
  }

  void previous() {
    if (state.items.isEmpty) return;
    final prev =
        (state.currentIndex - 1 + state.items.length) % state.items.length;
    state = state.copyWith(currentIndex: prev);
  }

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  void clear() => state = const QueueState();
}

final queueProvider =
    StateNotifierProvider<QueueNotifier, QueueState>((_) => QueueNotifier());

// ── Queue Screen ───────────────────────────────────────────────────

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.width > 600
          ? MediaQuery.of(context).size.height * 0.6
          : MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Up Next',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontFamily: 'Inter',
                    )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${queue.items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      )),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(queueProvider.notifier).toggleShuffle();
                  },
                  child: Icon(
                    Icons.shuffle_rounded,
                    color: queue.shuffle ? AppColors.accent : cs.onSurface.withValues(alpha: 0.45),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(queueProvider.notifier).clear();
                  },
                  child: Text('Clear All',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontFamily: 'Inter')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: queue.items.isEmpty
                ? Center(
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
                          child: const Icon(Icons.queue_music_rounded,
                              color: AppColors.accent, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Queue is empty',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Play a song or video to start a queue.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontFamily: 'Inter',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(0, 8, 0,
                        MediaQuery.of(context).padding.bottom + 90),
                    itemCount: queue.items.length,
                    onReorder: (oldIndex, newIndex) {
                      HapticFeedback.mediumImpact();
                      final adjusted =
                          newIndex > oldIndex ? newIndex - 1 : newIndex;
                      ref
                          .read(queueProvider.notifier)
                          .reorder(oldIndex, adjusted);
                    },
                    itemBuilder: (context, i) {
                      final item = queue.items[i];
                      final isCurrent = i == queue.currentIndex;
                      return ListTile(
                        key: ValueKey(item.id + i.toString()),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : AppColors.borderOf(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCurrent
                                ? Icons.equalizer_rounded
                                : (item.isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.music_note_rounded),
                            color: isCurrent
                                ? AppColors.accent
                                : cs.onSurface.withValues(alpha: 0.45),
                            size: 18,
                          ),
                        ),
                        title: Text(item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isCurrent ? AppColors.accent : cs.onSurface,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          item.artist ?? item.formattedDuration,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                        trailing: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(queueProvider.notifier).removeAt(i);
                          },
                          child: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: cs.onSurface.withValues(alpha: 0.45),
                              size: 20),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
