import 'dart:io';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_scanner_service.dart';
import '../../../core/database/played_database.dart';
import '../../../core/utils/shelf_sorter.dart';

/// Data layer for My Space.
class MediaRepository {
  MediaRepository._();
  static final MediaRepository instance = MediaRepository._();

  List<MediaItem>? _cachedItems;
  List<MediaItem>? get cachedItems => _cachedItems;

  Future<List<MediaItem>> getAllMedia({bool forceRefresh = false}) async {
    if (_cachedItems != null && !forceRefresh) return _cachedItems!;

    final scanned = await MediaScannerService.instance.scanAll();

    // MediaStore items have albumArtPath set — they are already confirmed
    // to exist by the OS. Skip File.exists() for them (saves thousands of
    // async I/O calls on large libraries).
    final mediaStoreItems = scanned.where((e) => e.albumArtPath != null).toList();
    final supplemental    = scanned.where((e) => e.albumArtPath == null).toList();

    final alive = <MediaItem>[...mediaStoreItems];

    // Verify supplemental (receive-dir) items in batches of 50
    // to avoid OOM on large libraries from one giant Future.wait()
    if (supplemental.isNotEmpty) {
      const batchSize = 50;
      for (var i = 0; i < supplemental.length; i += batchSize) {
        final batch = supplemental.skip(i).take(batchSize).toList();
        final checks = await Future.wait(
          batch.map((item) =>
              File(item.filePath).exists().catchError((_) => false)),
        );
        for (var j = 0; j < batch.length; j++) {
          if (checks[j]) alive.add(batch[j]);
        }
      }
    }

    _cachedItems = alive;

    // Fire-and-forget shelf cache update
    try {
      final bundle = ShelfSorter.buildAllShelves(alive);
      PlayedDatabase.instance
          .cacheShelf('cinema', bundle.cinemaShelf.map((e) => e.id).toList())
          .ignore();
      PlayedDatabase.instance
          .cacheShelf('street', bundle.streetTapesShelf.map((e) => e.id).toList())
          .ignore();
    } catch (_) {}

    return alive;
  }

  List<MediaItem> getRecentlyPlayed({int limit = 30}) {
    // If cache is ready, filter from it — zero I/O
    if (_cachedItems != null) {
      final cachedPaths = {for (final e in _cachedItems!) e.filePath};
      final history = PlayedDatabase.instance.getRecentlyPlayed(limit: limit * 2);
      return history
          .where((item) => cachedPaths.contains(item.filePath))
          .take(limit)
          .toList();
    }
    // Fallback: return history without blocking the main thread.
    // existsSync() on slow storage can freeze the UI for hundreds of ms;
    // stale entries are harmless — they are filtered on the next full scan.
    try {
      return PlayedDatabase.instance.getRecentlyPlayed(limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<void> recordPlay(MediaItem item) async {
    try { await PlayedDatabase.instance.recordPlay(item); } catch (_) {}
  }

  void invalidate() => _cachedItems = null;
}
