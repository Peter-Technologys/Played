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

    // Concurrent file-existence check — fast and non-blocking
    final checks = await Future.wait(
      scanned.map((item) => File(item.filePath).exists()
          .catchError((_) => false)),
    );
    final alive = <MediaItem>[
      for (var i = 0; i < scanned.length; i++)
        if (checks[i]) scanned[i],
    ];

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
    try {
      final history = PlayedDatabase.instance.getRecentlyPlayed(limit: limit * 2);
      return history
          .where((item) {
            try { return File(item.filePath).existsSync(); } catch (_) { return false; }
          })
          .take(limit)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordPlay(MediaItem item) async {
    try { await PlayedDatabase.instance.recordPlay(item); } catch (_) {}
  }

  void invalidate() => _cachedItems = null;
}
