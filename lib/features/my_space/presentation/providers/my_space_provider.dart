import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/database/played_database.dart';
import '../../data/media_repository.dart';

/// The full media library — all songs + all videos.
/// Two-phase loading:
///   Phase 1: return cached Hive data instantly (zero wait).
///   Phase 2: run a fresh MediaStore scan in the background,
///            update the provider silently (no spinner shown).
final mediaLibraryProvider =
    AsyncNotifierProvider<MediaLibraryNotifier, List<MediaItem>>(
  MediaLibraryNotifier.new,
);

class MediaLibraryNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    // Phase 1 — serve cached items from Hive immediately
    final cached = PlayedDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (cached.isNotEmpty) {
      // Kick off background refresh without awaiting
      _backgroundRefresh();
      return cached;
    }
    // First install — no cache yet, do a foreground scan (one time only)
    return MediaRepository.instance.getAllMedia(forceRefresh: true);
  }

  /// Scans MediaStore in a background isolate, then silently updates state.
  Future<void> _backgroundRefresh() async {
    try {
      // Run the scan off the main thread
      final fresh = await Isolate.run(
        () => MediaRepository.instance.getAllMedia(forceRefresh: true),
      );
      state = AsyncData(fresh);
    } catch (e) {
      // Keep showing cached data — don't surface the error
    }
  }

  /// Called by the refresh button — shows a brief loading state.
  Future<void> refresh() async {
    MediaRepository.instance.invalidate();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => MediaRepository.instance.getAllMedia(forceRefresh: true),
    );
  }
}

// Legacy provider kept for MediaCard compatibility
final mySpaceProvider = mediaLibraryProvider;
