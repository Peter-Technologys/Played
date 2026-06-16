import 'dart:async';
import 'dart:io';
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
/// Fires whenever any file is added/removed/modified on the device
/// (USB copy, file manager, SD card, AirDrop receive, Xender, etc.)
const _mediaEventChannel = EventChannel('com.petersmart.played/media_events');

/// The full media library — all songs + all videos.
///
/// Three-phase loading:
///   Phase 1: in-memory cache or Hive seed → instant UI
///   Phase 2: background compute() scan → silent update
///   Phase 3: live MediaStore observer → auto-refresh on new files
final mediaLibraryProvider =
    AsyncNotifierProvider<MediaLibraryNotifier, List<MediaItem>>(
  MediaLibraryNotifier.new,
);

class MediaLibraryNotifier extends AsyncNotifier<List<MediaItem>> {
  StreamSubscription<dynamic>? _mediaObserver;
  Timer? _debounce;

  @override
  Future<List<MediaItem>> build() async {
    // Start listening to live MediaStore changes (USB, file manager, etc.)
    _startMediaObserver();

    // Phase 1a — in-memory cache (zero I/O, instant)
    final cached = MediaRepository.instance.cachedItems;
    if (cached != null && cached.isNotEmpty) {
      _backgroundRefresh();
      return cached;
    }

    // Phase 1b — Hive play-history as seed so UI is never blank
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 9999);
    if (history.isNotEmpty) {
      _backgroundRefresh();
      return history;
    }

    // First install — foreground scan (one time only, shows shimmer)
    return MediaRepository.instance.getAllMedia(forceRefresh: true);
  }

  /// Listens to Android MediaStore change events.
  /// Debounced 1.5s so rapid file copies don't spam re-scans.
  void _startMediaObserver() {
    _mediaObserver?.cancel();
    try {
      _mediaObserver = _mediaEventChannel
          .receiveBroadcastStream()
          .listen((_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 1500), () {
          debugPrint('[MediaLibrary] MediaStore changed — auto-refreshing...');
          _backgroundRefresh();
        });
      });
    } catch (e) {
      debugPrint('[MediaLibrary] MediaObserver not available: $e');
    }
  }

  /// Runs a fresh scan via compute() (background isolate),
  /// then silently replaces state. No spinner shown to the user.
  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await compute(_runScan, true);
      if (fresh.isNotEmpty) state = AsyncData(fresh);
    } catch (e) {
      debugPrint('[MediaLibrary] Background refresh failed: $e');
    }
  }

  /// Manual pull-to-refresh.
  Future<void> refresh() async {
    MediaRepository.instance.invalidate();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => MediaRepository.instance.getAllMedia(forceRefresh: true),
    );
  }

  @override
  void dispose() {
    _mediaObserver?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

// Alias kept for MediaCard and other widgets
final mySpaceProvider = mediaLibraryProvider;
