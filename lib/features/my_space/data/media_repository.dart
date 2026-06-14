import 'dart:io';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_scanner_service.dart';
import '../../../core/database/played_database.dart';
import '../../../core/utils/shelf_sorter.dart';

/// Data layer for My Space — wraps MediaScannerService
/// and provides caching via PlayedDatabase.
class MediaRepository {
  MediaRepository._();
  static final MediaRepository instance = MediaRepository._();

  List<MediaItem>? _cachedItems;

  /// Exposes the current in-memory cache (may be null before first scan).
  List<MediaItem>? get cachedItems => _cachedItems;

  /// Returns all scanned media items.
  /// Filters out files that no longer exist on disk (deleted externally).
  /// Uses in-memory cache after first scan.
  Future<List<MediaItem>> getAllMedia({bool forceRefresh = false}) async {
    if (_cachedItems != null && !forceRefresh) return _cachedItems!;

    final scanned = await MediaScannerService.instance.scanAll();

    // Guard: remove items whose file was deleted since last scan
    final alive = <MediaItem>[];
    for (final item in scanned) {
      if (await File(item.filePath).exists()) {
        alive.add(item);
      }
    }

    _cachedItems = alive;

    // Persist shelf caches
    final bundle = ShelfSorter.buildAllShelves(alive);
    await PlayedDatabase.instance.cacheShelf(
        'cinema', bundle.cinemaShelf.map((e) => e.id).toList());
    await PlayedDatabase.instance.cacheShelf(
        'street', bundle.streetTapesShelf.map((e) => e.id).toList());
    return alive;
  }

  /// Returns recently played items, filtering out deleted files.
  List<MediaItem> getRecentlyPlayed({int limit = 30}) {
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: limit * 2);
    final alive = history
        .where((item) => File(item.filePath).existsSync())
        .take(limit)
        .toList();
    return alive;
  }

  /// Records a play event for [item].
  Future<void> recordPlay(MediaItem item) =>
      PlayedDatabase.instance.recordPlay(item);

  /// Clears the in-memory cache, forcing a fresh scan next call.
  void invalidate() => _cachedItems = null;
}
