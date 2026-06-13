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

  /// Returns all scanned media items.
  /// Uses in-memory cache after first scan.
  Future<List<MediaItem>> getAllMedia({bool forceRefresh = false}) async {
    if (_cachedItems != null && !forceRefresh) return _cachedItems!;
    final items = await MediaScannerService.instance.scanAll();
    _cachedItems = items;
    // Persist shelf caches
    final bundle = ShelfSorter.buildAllShelves(items);
    await PlayedDatabase.instance.cacheShelf(
        'cinema', bundle.cinemaShelf.map((e) => e.id).toList());
    await PlayedDatabase.instance.cacheShelf(
        'street', bundle.streetTapesShelf.map((e) => e.id).toList());
    return items;
  }

  /// Returns recently played items from the local database.
  List<MediaItem> getRecentlyPlayed({int limit = 30}) =>
      PlayedDatabase.instance.getRecentlyPlayed(limit: limit);

  /// Records a play event for [item].
  Future<void> recordPlay(MediaItem item) =>
      PlayedDatabase.instance.recordPlay(item);

  /// Clears the in-memory cache, forcing a fresh scan next call.
  void invalidate() => _cachedItems = null;
}
