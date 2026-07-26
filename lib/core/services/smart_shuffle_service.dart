// lib/core/services/smart_shuffle_service.dart
//
// SmartShuffleService — weighted shuffle based on play count, recency,
// user rating, and skip rate. Pure Dart, no external AI SDK.
//
// Weight formula per track:
//   score = (ratingWeight * rating)
//         + (playWeight   * log(playCount + 1))
//         + (recencyWeight * recencyScore)
//         - (skipPenalty  * skipRate)
//
// Tracks with higher scores are more likely to appear early in the shuffled
// list. A small random jitter prevents the order from being deterministic.

import 'dart:math';

/// Holds per-track listening statistics used by [SmartShuffleService].
class TrackStats {
  /// Total number of times the track has been played to completion.
  final int playCount;

  /// Unix timestamp (ms) of the last time the track was played.
  /// Use 0 if the track has never been played.
  final int lastPlayedMs;

  /// User-assigned rating from 0 (unrated) to 5 (loved).
  final double rating;

  /// Total number of times the user skipped this track before it finished.
  final int skipCount;

  const TrackStats({
    required this.playCount,
    required this.lastPlayedMs,
    required this.rating,
    required this.skipCount,
  });
}

/// Provides a weighted shuffle of track IDs based on listening statistics.
class SmartShuffleService {
  SmartShuffleService._();
  static final SmartShuffleService instance = SmartShuffleService._();

  // ── Tuning constants ──────────────────────────────────────────────────────

  static const double _ratingWeight  = 3.0;
  static const double _playWeight    = 1.5;
  static const double _recencyWeight = 2.0;
  static const double _skipPenalty   = 2.5;

  /// Half-life for recency decay: tracks played within this window score
  /// close to 1.0; tracks played much longer ago score close to 0.
  static const Duration _recencyHalfLife = Duration(days: 14);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns a new list of [trackIds] ordered by descending weighted score,
  /// with a small random jitter so repeated calls produce different orderings
  /// for tracks with similar scores.
  ///
  /// Tracks absent from [stats] are treated as unplayed (score = 0 + jitter).
  List<String> smartShuffle(
    List<String> trackIds,
    Map<String, TrackStats> stats,
  ) {
    if (trackIds.isEmpty) return [];

    final rng = Random();
    final now = DateTime.now().millisecondsSinceEpoch;

    final scored = trackIds.map((id) {
      final s     = stats[id];
      final score = s == null ? 0.0 : _score(s, now);
      // Add ±0.5 jitter so equal-scored tracks shuffle differently each call.
      final jitter = rng.nextDouble() - 0.5;
      return _ScoredTrack(id: id, score: score + jitter);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((t) => t.id).toList();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  double _score(TrackStats s, int nowMs) {
    final ratingScore  = _ratingWeight * s.rating;
    final playScore    = _playWeight   * log(s.playCount + 1);
    final recencyScore = _recencyWeight * _recency(s.lastPlayedMs, nowMs);
    final skipRate     = s.playCount > 0
        ? s.skipCount / (s.playCount + s.skipCount)
        : 0.0;
    final skipScore    = _skipPenalty * skipRate;

    return ratingScore + playScore + recencyScore - skipScore;
  }

  /// Exponential decay: returns 1.0 if played right now, approaching 0 as
  /// time since last play grows. Uses [_recencyHalfLife] as the half-life.
  double _recency(int lastPlayedMs, int nowMs) {
    if (lastPlayedMs <= 0) return 0.0;
    final elapsedMs = (nowMs - lastPlayedMs).toDouble().clamp(0.0, double.infinity);
    final halfLifeMs = _recencyHalfLife.inMilliseconds.toDouble();
    return pow(0.5, elapsedMs / halfLifeMs).toDouble();
  }
}

class _ScoredTrack {
  final String id;
  final double score;
  const _ScoredTrack({required this.id, required this.score});
}
