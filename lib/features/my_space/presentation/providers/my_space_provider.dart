import 'dart:async';
import 'dart:isolate';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/database/played_database.dart';
import '../../data/media_repository.dart';
import 'package:flutter/services.dart';

// Top-level function required by compute() — must not be a closure.
Future<List<MediaItem>> _runScan(bool _) =>
    MediaRepository.instance.getAllMedia(forceRefresh: true);

/// Live media change event stream from Android MediaStore.
/// Channel name MUST match the one registered in MainActivity.kt.
const _mediaEventChannel = EventChannel('com.otyaplayer.app/media_events');

/// The full media library — all songs + all videos.
///
/// Loading strategy (offline-first, instant UI):
///   Phase 1a: in-memory cache          → 0 ms, truly instant
///   Phase 1b: Hive history seed        → ~5 ms, never blank on cold start
///   Phase 2:  background scan via      → silent update, no shimmer
///             MediaStore (fast, ~200ms)
///   Phase 3:  live MediaStore observer → auto-refresh on new files
final mediaLibraryProvider =
    AsyncNotifierProvider<MediaLibraryNotifier, List<MediaItem>>(
  MediaLibraryNotifier.new,
);

class MediaLibraryNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    StreamSubscription<dynamic>? sub;
    Timer? debounce;

    try {
      sub = _mediaEventChannel.receiveBroadcastStream().listen((_) {
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 3), _backgroundRefresh);
      });
    } catch (e) {
      debugPrint('[MediaLibrary] MediaObserver not available: $e');
    }

    final periodicTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _backgroundRefresh();
    });

    ref.onDispose(() {
      debounce?.cancel();
      sub?.cancel();
      periodicTimer.cancel();
    });

    // Phase 1a — in-memory cache (zero I/O, truly instant)
    final cached = MediaRepository.instance.cachedItems;
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return cached;
    }

    // Phase 1b — Hive history seed (< 5 ms).
    // Returns recently played files immediately so the user sees their
    // library at once. Full scan runs silently in the background.
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (history.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return history;
    }

    // First install — no cache, no history.
    // Return empty immediately so the UI renders (shimmer covers it),
    // then populate via background scan.
    Future.microtask(_backgroundRefresh);
    return const [];
  }

  Future<void> _backgroundRefresh() async {
    try {
      List<MediaItem> fresh;
      try {
        // Attempt to run on a separate isolate for UI thread isolation.
        // Falls back to main isolate if the isolate cannot be spawned —
        // this happens when MediaRepository holds MethodChannel references
        // that cannot be transferred across isolate boundaries.
        fresh = await compute(_runScan, true);
      } on IsolateSpawnException {
        debugPrint('[MediaLibrary] Isolate spawn failed — running on main isolate.');
        fresh = await _runScan(true);
      }
      if (fresh.isNotEmpty) state = AsyncData(fresh);
    } catch (e) {
      debugPrint('[MediaLibrary] Background refresh failed: $e');
      // Keep previous state — never wipe library on error
    }
  }

  /// Silent background refresh — never shows loading shimmer.
  Future<void> backgroundRefresh() async {
    MediaRepository.instance.invalidate();
    await _backgroundRefresh();
  }

  /// refresh() also runs silently.
  Future<void> refresh() async {
    MediaRepository.instance.invalidate();
    await _backgroundRefresh();
  }
}

// Alias kept for MediaCard and other widgets
final mySpaceProvider = mediaLibraryProvider;
