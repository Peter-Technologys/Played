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
  @override
  Future<List<MediaItem>> build() async {
    // Subscribe to live MediaStore changes — auto-refresh on any file add
    // (USB, file manager, SD card, Xender, Bluetooth, WhatsApp, etc.)
    StreamSubscription<dynamic>? sub;
    Timer? debounce;
    try {
      sub = _mediaEventChannel.receiveBroadcastStream().listen((_) {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 1500), _backgroundRefresh);
      });
    } catch (e) {
      debugPrint('[MediaLibrary] MediaObserver not available: $e');
    }
    // AsyncNotifier uses ref.onDispose — no override needed
    ref.onDispose(() {
      debounce?.cancel();
      sub?.cancel();
    });

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

    // First install — foreground scan
    return MediaRepository.instance.getAllMedia(forceRefresh: true);
  }

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await compute(_runScan, true);
      if (fresh.isNotEmpty) state = AsyncData(fresh);
    } catch (e) {
      debugPrint('[MediaLibrary] Background refresh failed: $e');
    }
  }

  /// Silent background refresh — never shows loading shimmer.
  Future<void> backgroundRefresh() async {
    MediaRepository.instance.invalidate();
    await _backgroundRefresh();
  }

  /// refresh() also runs silently — shimmer only on true first load.
  Future<void> refresh() async {
    MediaRepository.instance.invalidate();
    await _backgroundRefresh();
  }
}

// Alias kept for MediaCard and other widgets
final mySpaceProvider = mediaLibraryProvider;
