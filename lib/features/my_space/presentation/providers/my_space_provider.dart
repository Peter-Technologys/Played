import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/database/played_database.dart';
import '../../data/media_repository.dart';

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
  // A4: Single debounce guard inside the notifier so that multiple callers
  // (VideoTabScreen + MusicTabScreen both alive via AutomaticKeepAliveClientMixin)
  // never double-fire a background refresh within 2 seconds of each other.
  Timer? _resumeDebounce;

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
      _resumeDebounce?.cancel();
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
      // MethodChannels (used by MediaScannerService) cannot cross isolate
      // boundaries — compute() always fails with MissingPluginException.
      // Run the scan directly on the main isolate; it is fully async so
      // it does not block the UI thread.
      final fresh = await MediaRepository.instance.getAllMedia(forceRefresh: true);
      // Guard: ref may have been disposed if the user navigated away
      // during the scan. Accessing state on a disposed ref throws.
      if (fresh.isNotEmpty) {
        try {
          state = AsyncData(fresh);
        } catch (_) {
          // Ref disposed — ignore silently
        }

        // A1: Write fresh scan results back to Hive history so the next
        // cold start can seed from them instantly (Phase 1b). We only
        // upsert items that are not already in history to avoid overwriting
        // lastPlayedAt timestamps for recently played tracks.
        _writeBackToHive(fresh).ignore();
      }
    } catch (e) {
      debugPrint('[MediaLibrary] Background refresh failed: $e');
      // Keep previous state — never wipe library on error
    }
  }

  /// A1: Upsert fresh scan results into the Hive history box so Phase 1b
  /// seed is always populated after the first scan. Only items not already
  /// in history are written, preserving lastPlayedAt for played tracks.
  Future<void> _writeBackToHive(List<MediaItem> items) async {
    try {
      final db = PlayedDatabase.instance;
      // Build a set of IDs already in history for O(1) lookup.
      final existing = LinkedHashSet<String>.from(
        db.getRecentlyPlayed(limit: 9999).map((e) => e.id),
      );
      for (final item in items) {
        if (!existing.contains(item.id)) {
          // seedLibraryItem writes the item WITHOUT stamping lastPlayedAt,
          // so library items never appear as 'recently played' with today's
          // timestamp, preserving the integrity of play history.
          await db.seedLibraryItem(item);
        }
      }
    } catch (e) {
      debugPrint('[MediaLibrary] Hive write-back failed: $e');
    }
  }

  /// A4: Silent background refresh with a single debounce guard.
  /// Both VideoTabScreen and MusicTabScreen call this on app resume.
  /// The guard ensures only one actual refresh fires within 2 seconds,
  /// preventing the double-fire caused by AutomaticKeepAliveClientMixin
  /// keeping both tabs alive simultaneously.
  Future<void> backgroundRefresh() async {
    _resumeDebounce?.cancel();
    _resumeDebounce = Timer(const Duration(seconds: 2), () async {
      MediaRepository.instance.invalidate();
      await _backgroundRefresh();
    });
  }

  /// refresh() also runs silently.
  Future<void> refresh() async {
    MediaRepository.instance.invalidate();
    await _backgroundRefresh();
  }
}

// Alias kept for MediaCard and other widgets
final mySpaceProvider = mediaLibraryProvider;
