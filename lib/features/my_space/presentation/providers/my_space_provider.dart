import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/database/played_database.dart';
import '../../data/media_repository.dart';

// Top-level function required by compute() — must not be a closure.
Future<List<MediaItem>> _runScan(bool _) =>
    MediaRepository.instance.getAllMedia(forceRefresh: true);

/// The full media library — all songs + all videos.
///
/// Two-phase loading (no spinner on reopen):
///   Phase 1: in-memory cache → Hive history seed → foreground scan
///   Phase 2: compute() background scan, silently updates state
final mediaLibraryProvider =
    AsyncNotifierProvider<MediaLibraryNotifier, List<MediaItem>>(
  MediaLibraryNotifier.new,
);

class MediaLibraryNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    // Phase 1a — in-memory cache (zero I/O, instant)
    final cached = MediaRepository.instance.cachedItems;
    if (cached != null && cached.isNotEmpty) {
      _backgroundRefresh();
      return cached;
    }

    // Phase 1b — Hive play-history as seed so UI is never blank
    // This is instant (Hive is already open from main.dart)
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (history.isNotEmpty) {
      _backgroundRefresh();
      return history;
    }

    // First install — foreground scan (one time only, shows shimmer)
    return MediaRepository.instance.getAllMedia(forceRefresh: true);
  }

  /// Runs a fresh MediaStore scan via compute() (background isolate),
  /// then silently replaces state. No spinner shown to the user.
  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await compute(_runScan, true);
      if (fresh.isNotEmpty) state = AsyncData(fresh);
    } catch (e) {
      debugPrint('[MediaLibrary] Background refresh failed: $e');
      // Keep cached data on error — never crash the UI
    }
  }

  /// Manual pull-to-refresh — brief loading state then update.
  Future<void> refresh() async {
    MediaRepository.instance.invalidate();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => MediaRepository.instance.getAllMedia(forceRefresh: true),
    );
  }
}

// Alias kept for MediaCard and other widgets
final mySpaceProvider = mediaLibraryProvider;
