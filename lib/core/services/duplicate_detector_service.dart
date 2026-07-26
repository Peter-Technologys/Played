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
  static final DuplicateDetectorService instance = DuplicateDetectorService._();

  // ── Tuning constants ──────────────────────────────────────────────────────

  /// Maximum Levenshtein distance (on normalised titles) to consider two
  /// tracks as title-similar. Expressed as a fraction of the longer title's
  /// length so it scales with title length.
  static const double _maxTitleDistanceRatio = 0.2;

  /// Maximum absolute duration difference in milliseconds (2 seconds).
  static const int _maxDurationDiffMs = 2000;

  /// Maximum relative file-size difference (5%).
  static const double _maxSizeRatio = 0.05;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns groups of duplicate track IDs.
  ///
  /// Each inner list contains two or more track IDs that are considered
  /// duplicates of each other. Tracks that have no duplicates are omitted.
  List<List<String>> findDuplicates(List<TrackMeta> tracks) {
    if (tracks.length < 2) return [];

    // Union-Find to group duplicates transitively.
    final parent = <String, String>{};
    for (final t in tracks) parent[t.id] = t.id;

    String find(String id) {
      if (parent[id] != id) parent[id] = find(parent[id]!);
      return parent[id]!;
    }

    void union(String a, String b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    // O(n²) pairwise comparison — acceptable for typical library sizes.
    for (int i = 0; i < tracks.length; i++) {
      for (int j = i + 1; j < tracks.length; j++) {
        if (_areDuplicates(tracks[i], tracks[j])) {
          union(tracks[i].id, tracks[j].id);
        }
      }
    }

    // Collect groups.
    final groups = <String, List<String>>{};
    for (final t in tracks) {
      final root = find(t.id);
      groups.putIfAbsent(root, () => []).add(t.id);
    }

    // Return only groups with 2+ members.
    return groups.values.where((g) => g.length >= 2).toList();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  bool _areDuplicates(TrackMeta a, TrackMeta b) {
    // 1. Duration within 2 seconds.
    if ((a.durationMs - b.durationMs).abs() > _maxDurationDiffMs) return false;

    // 2. File size within 5%.
    if (!_sizeWithinThreshold(a.fileSizeBytes, b.fileSizeBytes)) return false;

    // 3. Normalised title similarity.
    final normA = _normalise(a.title);
    final normB = _normalise(b.title);
    final maxLen = normA.length > normB.length ? normA.length : normB.length;
    if (maxLen == 0) return true; // both empty → same
    final dist = _levenshtein(normA, normB);
    return dist / maxLen <= _maxTitleDistanceRatio;
  }

  bool _sizeWithinThreshold(int sizeA, int sizeB) {
    if (sizeA == 0 && sizeB == 0) return true;
    if (sizeA == 0 || sizeB == 0) return false;
    final larger  = sizeA > sizeB ? sizeA : sizeB;
    final smaller = sizeA < sizeB ? sizeA : sizeB;
    return (larger - smaller) / larger <= _maxSizeRatio;
  }

  /// Normalise a title for comparison: lowercase, strip punctuation/articles,
  /// collapse whitespace.
  String _normalise(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'\b(the|a|an|feat|ft|official|audio|video|lyrics|hd|4k|remix|remaster|remastered)\b'), '')
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

    // Use two rows to save memory.
    var prev = List<int>.generate(tLen + 1, (i) => i);
    var curr = List<int>.filled(tLen + 1, 0);

    for (int i = 1; i <= sLen; i++) {
      curr[0] = i;
      for (int j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = _min3(
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }

    return prev[tLen];
  }

  int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= c) return b;
    return c;
  }
}
