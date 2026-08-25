import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/providers/duplicates_provider.dart';
import '../../../../core/services/duplicate_detector_service.dart';
import '../../../../core/database/otya_database.dart';
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

  // STABILITY 2: Incremental Set of known Hive IDs — populated once and
  // updated incrementally so _writeBackToHive never does a full O(n) Hive
  // read on every background refresh.
  Set<String>? _knownHiveIds;

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
      // Fix #8: lifecycleState can be null on the first frame (before the
      // first didChangeAppLifecycleState callback fires). Guard against null
      // so we don't accidentally scan when the state is unknown.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle != AppLifecycleState.resumed) return;
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
    final history = OtyaDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (history.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return history;
    }

    // Fix #19: Fresh install with files already on device — history is empty
    // but the shelf cache may have been populated by a previous scan (e.g.
    // after an app update that cleared history). Reconstruct a seed list from
    // the cached shelf IDs mapped back to Hive history items.
    final db = OtyaDatabase.instance;
    final cinemaIds = db.getShelfCache('cinema');
    final streetIds = db.getShelfCache('street');
    if (cinemaIds.isNotEmpty || streetIds.isNotEmpty) {
      final allCachedIds = {...cinemaIds, ...streetIds};
      // getRecentlyPlayed(limit:9999) already returned empty, so the history
      // box is empty. Fall through to the background scan which will populate
      // it; but return the shelf-cache IDs as a stub so the UI isn't blank.
      // We can't reconstruct full MediaItems from IDs alone without the scan,
      // so trigger the scan and return empty — the scan will update state.
      Future.microtask(_backgroundRefresh);
      debugPrint('[MediaLibrary] Shelf cache has ${allCachedIds.length} IDs — '
          'triggering background scan for cold-start population.');
      return const [];
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

        // Run duplicate detection after every successful scan and expose
        // results via duplicatesProvider so the UI can surface them.
        _detectDuplicates(fresh);
      }
    } catch (e) {
      debugPrint('[MediaLibrary] Background refresh failed: $e');
      // Keep previous state — never wipe library on error
    }
  }

  /// Runs [DuplicateDetectorService.findDuplicates] on [items] and updates
  /// [duplicatesProvider] with the result.
  void _detectDuplicates(List<MediaItem> items) {
    try {
      final metas = items.map((item) => TrackMeta(
        id:            item.id,
        title:         item.title,
        durationMs:    item.duration?.inMilliseconds ?? 0,
        fileSizeBytes: item.fileSizeBytes,
      )).toList();
      final groups = DuplicateDetectorService.instance.findDuplicates(metas);
      try {
        ref.read(duplicatesProvider.notifier).state = groups;
      } catch (_) {
        // ref disposed — ignore
      }
      if (groups.isNotEmpty) {
        debugPrint('[MediaLibrary] Duplicates found: ${groups.length} group(s).');
      }
    } catch (e) {
      debugPrint('[MediaLibrary] Duplicate detection failed (non-fatal): $e');
    }
  }

  /// A1: Upsert fresh scan results into the Hive history box so Phase 1b
  /// seed is always populated after the first scan. Only items not already
  /// in history are written, preserving lastPlayedAt for played tracks.
  ///
  /// STABILITY 2: Uses an incremental Set<String> (_knownHiveIds) that is
  /// populated once and updated as new items are written — avoids the O(n)
  /// getRecentlyPlayed(limit:9999) call on every background refresh.
  Future<void> _writeBackToHive(List<MediaItem> items) async {
    try {
      final db = OtyaDatabase.instance;
      // Populate the known-IDs set on first call only.
      _knownHiveIds ??= LinkedHashSet<String>.from(
        db.getRecentlyPlayed(limit: 9999).map((e) => e.id),
      );
      for (final item in items) {
        if (!_knownHiveIds!.contains(item.id)) {
          // seedLibraryItem writes the item WITHOUT stamping lastPlayedAt,
          // so library items never appear as 'recently played' with today's
          // timestamp, preserving the integrity of play history.
          await db.seedLibraryItem(item);
          // Update the incremental set so subsequent calls stay O(1).
          _knownHiveIds!.add(item.id);
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
