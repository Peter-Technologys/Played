// lib/core/services/duplicate_detector_service.dart
//
// DuplicateDetectorService — finds groups of duplicate tracks using three
// heuristics:
//   1. Normalised title similarity (Levenshtein distance ≤ threshold)
//   2. Duration within 2 seconds of each other
//   3. File size within 5% of each other
//
// Two tracks are considered duplicates when ALL three conditions hold.
// Returns groups (lists) of track IDs where every member is a duplicate of
// every other member in the group.

/// Metadata for a single track used by [DuplicateDetectorService].
class TrackMeta {
  /// Unique identifier for this track (e.g. file path or UUID).
  final String id;

  /// Display title of the track (used for similarity comparison).
  final String title;

  /// Duration in milliseconds.
  final int durationMs;

  /// File size in bytes.
  final int fileSizeBytes;

  const TrackMeta({
    required this.id,
    required this.title,
    required this.durationMs,
    required this.fileSizeBytes,
  });
}

/// Detects groups of duplicate tracks using title similarity, duration, and
/// file size heuristics.
class DuplicateDetectorService {
  DuplicateDetectorService._();
  static final DuplicateDetectorService instance =
      DuplicateDetectorService._();

  static const double _maxTitleDistanceRatio = 0.2;
  static const int _maxDurationDiffMs = 2000;
  static const double _maxSizeRatio = 0.05;

  /// Returns groups of duplicate track IDs.
  List<List<String>> findDuplicates(List<TrackMeta> tracks) {
    if (tracks.length < 2) return [];

    final parent = <String, String>{};
    for (final track in tracks) {
      parent[track.id] = track.id;
    }

    String find(String id) {
      if (parent[id] != id) {
        parent[id] = find(parent[id]!);
      }
      return parent[id]!;
    }

    void union(String a, String b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA != rootB) {
        parent[rootA] = rootB;
      }
    }

    for (var i = 0; i < tracks.length; i++) {
      for (var j = i + 1; j < tracks.length; j++) {
        if (_areDuplicates(tracks[i], tracks[j])) {
          union(tracks[i].id, tracks[j].id);
        }
      }
    }

    final groups = <String, List<String>>{};
    for (final track in tracks) {
      final root = find(track.id);
      groups.putIfAbsent(root, () => []).add(track.id);
    }

    return groups.values.where((group) => group.length >= 2).toList();
  }

  bool _areDuplicates(TrackMeta a, TrackMeta b) {
    if ((a.durationMs - b.durationMs).abs() > _maxDurationDiffMs) {
      return false;
    }
    if (!_sizeWithinThreshold(a.fileSizeBytes, b.fileSizeBytes)) {
      return false;
    }

    final normA = _normalise(a.title);
    final normB = _normalise(b.title);
    final maxLen = normA.length > normB.length ? normA.length : normB.length;
    if (maxLen == 0) return true;
    final distance = _levenshtein(normA, normB);
    return distance / maxLen <= _maxTitleDistanceRatio;
  }

  bool _sizeWithinThreshold(int sizeA, int sizeB) {
    if (sizeA == 0 && sizeB == 0) return true;
    if (sizeA == 0 || sizeB == 0) return false;
    final larger = sizeA > sizeB ? sizeA : sizeB;
    final smaller = sizeA < sizeB ? sizeA : sizeB;
    return (larger - smaller) / larger <= _maxSizeRatio;
  }

  /// Normalise a title for comparison: lowercase, strip punctuation/articles,
  /// collapse whitespace.
  String _normalise(String title) {
    return title
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'\b(the|a|an|feat|ft|official|audio|video|lyrics|hd|4k|remix|remaster|remastered)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Standard iterative Levenshtein distance.
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final sLen = s.length;
    final tLen = t.length;
    var previous = List<int>.generate(tLen + 1, (index) => index);
    var current = List<int>.filled(tLen + 1, 0);

    for (var i = 1; i <= sLen; i++) {
      current[0] = i;
      for (var j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        current[j] = _min3(
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        );
      }
      final temporary = previous;
      previous = current;
      current = temporary;
    }

    return previous[tLen];
  }

  int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= c) return b;
    return c;
  }
}
