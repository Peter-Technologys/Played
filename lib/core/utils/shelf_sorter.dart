import '../models/media_item.dart';

/// Automated sorting engine that groups media files
/// into dynamic shelves based on duration and metadata.
abstract class ShelfSorter {
  // ── Thresholds ─────────────────────────────────────────────
  static const Duration _cinemaThreshold = Duration(minutes: 45);
  static const Duration _streetTapeThreshold = Duration(minutes: 20);

  static const List<String> _streetTapeKeywords = [
    'dj',
    'mix',
    'remix',
    'mixtape',
    'mashup',
    'blend',
  ];

  // ── Public API ─────────────────────────────────────────────

  /// Returns all video files longer than 45 minutes.
  static List<MediaItem> getCinemaShelf(List<MediaItem> allMedia) {
    return allMedia
        .where((item) =>
            item.isVideo &&
            item.duration != null &&
            item.duration! >= _cinemaThreshold)
        .toList()
      ..sort((a, b) => b.lastPlayedAt != null && a.lastPlayedAt != null
          ? b.lastPlayedAt!.compareTo(a.lastPlayedAt!)
          : 0);
  }

  /// Returns audio files longer than 20 minutes whose
  /// title/filename contains DJ, Mix, Remix, etc.
  static List<MediaItem> getStreetTapesShelf(List<MediaItem> allMedia) {
    return allMedia
        .where((item) =>
            !item.isVideo &&
            item.duration != null &&
            item.duration! >= _streetTapeThreshold &&
            _matchesStreetKeyword(item))
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  /// Returns all remaining media not captured by any shelf,
  /// sorted by most recently played for the unified timeline.
  static List<MediaItem> getRecentTimeline(
    List<MediaItem> allMedia, {
    int limit = 40,
  }) {
    final cinemaIds =
        getCinemaShelf(allMedia).map((e) => e.id).toSet();
    final streetIds =
        getStreetTapesShelf(allMedia).map((e) => e.id).toSet();

    final filtered = allMedia
        .where((item) =>
            !cinemaIds.contains(item.id) &&
            !streetIds.contains(item.id) &&
            item.lastPlayedAt != null)
        .toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));

    return filtered.take(limit).toList();
  }

  /// Groups all media into a named shelf map in one pass.
  static ShelfBundle buildAllShelves(List<MediaItem> allMedia) {
    return ShelfBundle(
      recentTimeline: getRecentTimeline(allMedia),
      cinemaShelf: getCinemaShelf(allMedia),
      streetTapesShelf: getStreetTapesShelf(allMedia),
    );
  }

  // ── Private Helpers ────────────────────────────────────────

  static bool _matchesStreetKeyword(MediaItem item) {
    final searchTarget =
        '${item.title} ${item.fileName}'.toLowerCase();
    return _streetTapeKeywords
        .any((keyword) => searchTarget.contains(keyword));
  }
}

/// Immutable result bundle from a single shelf-sort pass.
class ShelfBundle {
  final List<MediaItem> recentTimeline;
  final List<MediaItem> cinemaShelf;
  final List<MediaItem> streetTapesShelf;

  const ShelfBundle({
    required this.recentTimeline,
    required this.cinemaShelf,
    required this.streetTapesShelf,
  });

  bool get hasCinema => cinemaShelf.isNotEmpty;
  bool get hasStreetTapes => streetTapesShelf.isNotEmpty;
}
