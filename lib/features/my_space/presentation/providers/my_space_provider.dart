import 'dart:async';
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
const _mediaEventChannel = EventChannel('com.petersmart.played/media_events');

/// The full media library — all songs + all videos.
///
/// Loading strategy (offline-first):
///   Phase 1: in-memory cache or Hive history seed -> instant UI (0 ms)
///   Phase 2: background compute() scan -> silent update, no shimmer
///   Phase 3: live MediaStore observer -> auto-refresh on new files
final mediaLibraryProvider =
    AsyncNotifierProvider<MediaLibraryNotifier, List<MediaItem>>(
  MediaLibraryNotifier.new,
);

class MediaLibraryNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    StreamSubscription<dynamic>? sub;
    Timer? debounce;

    // Layer 3 — live MediaStore events (debounced 3 s)
    try {
      sub = _mediaEventChannel.receiveBroadcastStream().listen((_) {
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 3), _backgroundRefresh);
      });
    } catch (e) {
      debugPrint('[MediaLibrary] MediaObserver not available: $e');
    }

    // Periodic fallback every 15 min (was 5 min — saves battery)
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

    // Phase 1b — Hive history seed so UI is never blank on cold start.
    // Hive is already open (opened in main() before runApp), so this is
    // a synchronous in-memory read — no disk I/O.
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (history.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return history;
    }

    // First install — no cache, no history: foreground scan (once ever)
    return MediaRepository.instance.getAllMedia(forceRefresh: true);
  }

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await compute(_runScan, true);
      // Only update state if we got results — never wipe existing library on error
      if (fresh.isNotEmpty && mounted) state = AsyncData(fresh);
    } catch (e) {
      debugPrint('[MediaLibrary] Background refresh failed: $e');
      // Keep previous state — don't show error if we already have data
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
