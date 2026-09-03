import 'dart:async';
import 'dart:io';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_scanner_service.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/utils/shelf_sorter.dart';

/// Data layer for My Space.
class MediaRepository {
  MediaRepository._();
  static final MediaRepository instance = MediaRepository._();

  List<MediaItem>? _cachedItems;
  List<MediaItem>? get cachedItems => _cachedItems;
  bool _scanning = false;

  /// Completer that all concurrent callers await while a scan is in progress.
  /// Replaced with a fresh Completer on each new scan so callers never hold
  /// a stale reference to a completed Completer.
  Completer<List<MediaItem>>? _scanCompleter;

  Future<List<MediaItem>> getAllMedia({bool forceRefresh = false}) async {
    if (_cachedItems != null && !forceRefresh) return _cachedItems!;
    // Prevent concurrent scans — if a scan is already in progress, all
    // callers await the same Completer instead of busy-polling.
    if (_scanning) {
      _scanCompleter ??= Completer<List<MediaItem>>();
      return _scanCompleter!.future;
    }
    _scanning = true;
    _scanCompleter = Completer<List<MediaItem>>();
    try {
      final scanned = await MediaScannerService.instance.scanAll();

      // MediaStore identity is carried explicitly in mediaStoreId. Artwork is
      // optional (and videos normally have no albumArtPath), so artwork must
      // never be used to infer where an item came from.
      final mediaStoreItems =
          scanned.where((e) => e.mediaStoreId != null).toList();
      final supplemental =
          scanned.where((e) => e.mediaStoreId == null).toList();

      final alive = <MediaItem>[...mediaStoreItems];

      // Verify supplemental (receive-dir) items in batches of 50
      // to avoid OOM on large libraries from one giant Future.wait().
      if (supplemental.isNotEmpty) {
        const batchSize = 50;
        for (var i = 0; i < supplemental.length; i += batchSize) {
          final batch = supplemental.skip(i).take(batchSize).toList();
          final checks = await Future.wait(
            batch.map(
              (item) => File(item.filePath).exists().catchError((_) => false),
            ),
          );
          for (var j = 0; j < batch.length; j++) {
            if (checks[j]) alive.add(batch[j]);
          }
        }
      }

      _cachedItems = alive;

      // Fire-and-forget shelf cache update.
      try {
        final bundle = ShelfSorter.buildAllShelves(alive);
        OtyaDatabase.instance
            .cacheShelf('cinema', bundle.cinemaShelf.map((e) => e.id).toList())
            .ignore();
        OtyaDatabase.instance
            .cacheShelf('street', bundle.streetTapesShelf.map((e) => e.id).toList())
            .ignore();
      } catch (_) {}

      _scanCompleter?.complete(alive);
      return alive;
    } catch (e) {
      _scanCompleter?.completeError(e);
      rethrow;
    } finally {
      _scanning = false;
      _scanCompleter = null;
    }
  }

  List<MediaItem> getRecentlyPlayed({int limit = 30}) {
    // If cache is ready, filter from it — zero I/O.
    if (_cachedItems != null) {
      final cachedPaths = {for (final e in _cachedItems!) e.filePath};
      final history = OtyaDatabase.instance.getRecentlyPlayed(limit: limit * 2);
      return history
          .where((item) => cachedPaths.contains(item.filePath))
          .take(limit)
          .toList();
    }
    // Fallback: return history without blocking the main thread.
    // existsSync() on slow storage can freeze the UI for hundreds of ms;
    // stale entries are harmless — they are filtered on the next full scan.
    try {
      return OtyaDatabase.instance.getRecentlyPlayed(limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<void> recordPlay(MediaItem item) async {
    try {
      await OtyaDatabase.instance.recordPlay(item);
    } catch (_) {}
  }

  void invalidate() => _cachedItems = null;
}
