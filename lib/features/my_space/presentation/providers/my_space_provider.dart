import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/otya_database.dart';
import '../../../../core/models/media_item.dart';
import '../../../../core/providers/duplicates_provider.dart';
import '../../../../core/services/duplicate_detector_service.dart';
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
    final history = OtyaDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (history.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return history;
    }

    // Fresh install / empty local cache. Render the shell immediately, then
    // scan in the background. If Android denies media access, _backgroundRefresh
    // promotes that failure to AsyncError because there is no existing library
    // to preserve. Video/Music can then show PermissionDeniedScreen instead of
    // misleading the user with a permanent "No media found" state.
    final db = OtyaDatabase.instance;
    final cinemaIds = db.getShelfCache('cinema');
    final streetIds = db.getShelfCache('street');
    if (cinemaIds.isNotEmpty || streetIds.isNotEmpty) {
      final allCachedIds = {...cinemaIds, ...streetIds};
      Future.microtask(_backgroundRefresh);
      debugPrint(
        '[MediaLibrary] Shelf cache has ${allCachedIds.length} IDs — '
        'triggering background scan for cold-start population.',
      );
      return const [];
    }

    Future.microtask(_backgroundRefresh);
    return const [];
  }

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await MediaRepository.instance.getAllMedia(
        forceRefresh: true,
      );

      // An empty scan is a valid library result (for example a new phone with
      // no media). Publish it when the current library is also empty; otherwise
      // retain the prior non-empty snapshot to avoid flashing the library away
      // during transient MediaStore/OEM failures.
      final currentItems = state.valueOrNull ?? const <MediaItem>[];
      if (fresh.isNotEmpty || currentItems.isEmpty) {
        try {
          state = AsyncData(fresh);
        } catch (_) {
          return;
        }
      }

      if (fresh.isNotEmpty) {
        _writeBackToHive(fresh).ignore();
        _detectDuplicates(fresh);
      }
    } catch (error, stack) {
      debugPrint('[MediaLibrary] Background refresh failed: $error');
      final currentItems = state.valueOrNull ?? const <MediaItem>[];
      if (currentItems.isEmpty) {
        // With no usable local snapshot, swallowing the error makes permission
        // denial indistinguishable from a genuinely empty phone. Surface the
        // failure so Video/Music can offer recovery. Once a real library exists,
        // refresh failures remain non-destructive and silent.
        try {
          state = AsyncError(error, stack);
        } catch (_) {}
      }
    }
  }

  /// Runs [DuplicateDetectorService.findDuplicates] on [items] and updates
  /// [duplicatesProvider] with the result.
  void _detectDuplicates(List<MediaItem> items) {
    try {
      final metas = items
          .map(
            (item) => TrackMeta(
              id: item.id,
              title: item.title,
              durationMs: item.duration?.inMilliseconds ?? 0,
              fileSizeBytes: item.fileSizeBytes,
            ),
          )
          .toList();
      final groups = DuplicateDetectorService.instance.findDuplicates(metas);
      try {
        ref.read(duplicatesProvider.notifier).state = groups;
      } catch (_) {}
      if (groups.isNotEmpty) {
        debugPrint(
          '[MediaLibrary] Duplicates found: ${groups.length} group(s).',
        );
      }
    } catch (e) {
      debugPrint('[MediaLibrary] Duplicate detection failed (non-fatal): $e');
    }
  }

  /// Upsert fresh scan results into the Hive history box so Phase 1b seed is
  /// always populated after the first scan. Only items not already in history
  /// are written, preserving lastPlayedAt for played tracks.
  Future<void> _writeBackToHive(List<MediaItem> items) async {
    try {
      final db = OtyaDatabase.instance;
      _knownHiveIds ??= LinkedHashSet<String>.from(
        db.getRecentlyPlayed(limit: 9999).map((e) => e.id),
      );
      for (final item in items) {
        if (!_knownHiveIds!.contains(item.id)) {
          await db.seedLibraryItem(item);
          _knownHiveIds!.add(item.id);
        }
      }
    } catch (e) {
      debugPrint('[MediaLibrary] Hive write-back failed: $e');
    }
  }

  /// Silent background refresh with a single debounce guard.
  Future<void> backgroundRefresh() async {
    _resumeDebounce?.cancel();
    _resumeDebounce = Timer(const Duration(seconds: 2), () async {
      MediaRepository.instance.invalidate();
      await _backgroundRefresh();
    });
  }

  Future<void> refresh() async {
    MediaRepository.instance.invalidate();
    await _backgroundRefresh();
  }
}

// Alias kept for MediaCard and other widgets.
final mySpaceProvider = mediaLibraryProvider;
