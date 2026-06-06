import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';// ── Queue Provider ─────────────────────────────────────────────

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
    final next = state.shuffle
        ? (state.currentIndex +
                1 +
                (state.items.length - 1) *
                    (DateTime.now().millisecond % state.items.length)) %
            state.items.length
        : (state.currentIndex + 1) % state.items.length;
    state = state.copyWith(currentIndex: next);
  }

  void previous() {
    if (state.items.isEmpty) return;
    final prev = (state.currentIndex - 1 + state.items.length) %
        state.items.length;
    state = state.copyWith(currentIndex: prev);
  }

  void toggleShuffle() =>
      state = state.copyWith(shuffle: !state.shuffle);

  void clear() => state = const QueueState();
}

final queueProvider =
    StateNotifierProvider<QueueNotifier, QueueState>(
  (_) => QueueNotifier(),
);

// ── Queue Screen ───────────────────────────────────────────────

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Up Next',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'SpaceGrotesk',
                    )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${queue.items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SpaceGrotesk',
                      )),
                ),
                const Spacer(),
                // Shuffle toggle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(queueProvider.notifier).toggleShuffle();
                  },
                  child: Icon(
                    Icons.shuffle_rounded,
                    color: queue.shuffle
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                // Clear
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(queueProvider.notifier).clear();
                  },
                  child: const Text('Clear',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'SpaceGrotesk')),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),

          // Queue list
          Expanded(
            child: queue.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded,
                            color: AppColors.textSecondary, size: 40),
                        SizedBox(height: 12),
                        Text('Queue is empty',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontFamily: 'SpaceGrotesk')),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: queue.items.length,
                    onReorderItem: (old, newIdx) {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(queueProvider.notifier)
                          .reorder(old, newIdx);
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
                                : AppColors.border,
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
                                : AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                        title: Text(item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isCurrent
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                              fontFamily: 'SpaceGrotesk',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          item.artist ?? item.formattedDuration,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                        trailing: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(queueProvider.notifier)
                                .removeAt(i);
                          },
                          child: const Icon(Icons.remove_circle_outline_rounded,
                              color: AppColors.textSecondary, size: 20),
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
