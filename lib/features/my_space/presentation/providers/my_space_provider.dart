import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

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
  Timer? _resumeDebounce;
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

    final cached = MediaRepository.instance.cachedItems;
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return cached;
    }

    final history = OtyaDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (history.isNotEmpty) {
      Future.microtask(_backgroundRefresh);
      return history;
    }

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

      // A completed scan is authoritative even when it returns zero items.
      // Failures throw into the catch block below, where an existing library is
      // preserved. Treating a successful empty scan as "ignore" leaves files
      // visible after the user deletes or moves them.
      try {
        state = AsyncData(fresh);
      } catch (_) {
        return;
      }

      if (fresh.isNotEmpty) {
        _writeBackToHive(fresh).ignore();
      }

      // Always recompute duplicates so an empty/new library clears old groups.
      unawaited(_detectDuplicates(fresh));
    } catch (error, stack) {
      debugPrint('[MediaLibrary] Background refresh failed: $error');
      final currentItems = state.valueOrNull ?? const <MediaItem>[];
      if (currentItems.isEmpty) {
        try {
          state = AsyncError(error, stack);
        } catch (_) {}
      }
    }
  }

  Future<void> _detectDuplicates(List<MediaItem> items) async {
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
          .toList(growable: false);
      final groups = await Isolate.run<List<List<String>>>(
        () => DuplicateDetectorService.instance.findDuplicates(metas),
      );
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

final mySpaceProvider = mediaLibraryProvider;
