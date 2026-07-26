// lib/core/services/smart_ad_service.dart
//
// SmartAdService — decides when to show interstitial-style ads at AI-timed
// moments. No actual ad SDK is used; the service emits [AdEvent.show] on a
// stream that the UI layer listens to.
//
// Rules:
//   • Never show an ad during the first 2 tracks of a session.
//   • Never show an ad if the user is a Pro subscriber.
//   • Show an ad after every 5th completed track.
//   • Show an ad after a session of 20+ minutes with no ad shown.
//
// Usage:
//   SmartAdService.instance.onSessionStart();
//   SmartAdService.instance.adEvents.listen((event) {
//     if (event == AdEvent.show) { /* show interstitial */ }
//   });
//   // On each track completion:
//   SmartAdService.instance.onTrackCompleted(isPro: false);

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Events emitted by [SmartAdService.adEvents].
enum AdEvent {
  /// The UI should display an interstitial ad now.
  show,
}

/// Singleton that decides when to show ads based on session behaviour.
class SmartAdService {
  SmartAdService._();
  static final SmartAdService instance = SmartAdService._();

  // ── State ─────────────────────────────────────────────────────────────────

  final StreamController<AdEvent> _controller =
      StreamController<AdEvent>.broadcast();

  /// Stream of [AdEvent]s. Listen to this to know when to show an ad.
  Stream<AdEvent> get adEvents => _controller.stream;

  int _tracksCompletedThisSession = 0;
  DateTime? _sessionStartedAt;
  DateTime? _lastAdShownAt;

  /// How many tracks must complete before an ad is shown.
  static const int _adEveryNTracks = 5;

  /// Minimum session duration before a time-based ad fires.
  static const Duration _sessionAdThreshold = Duration(minutes: 20);

  /// Minimum tracks before any ad can be shown (first 2 are ad-free).
  static const int _graceTracks = 2;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call this when a new listening session begins (e.g. app foreground or
  /// first play after idle).
  void onSessionStart() {
    _tracksCompletedThisSession = 0;
    _sessionStartedAt = DateTime.now();
    _lastAdShownAt = null;
    debugPrint('[SmartAd] Session started.');
  }

  /// Call this each time a track plays to completion.
  ///
  /// [isPro] — if true, no ad will ever be emitted.
  void onTrackCompleted(bool isPro) {
    if (isPro) {
      debugPrint('[SmartAd] Pro user — skipping ad logic.');
      return;
    }

    _tracksCompletedThisSession++;
    debugPrint('[SmartAd] Track completed — total this session: $_tracksCompletedThisSession');

    // Grace period: no ads during the first [_graceTracks] tracks.
    if (_tracksCompletedThisSession <= _graceTracks) {
      debugPrint('[SmartAd] Within grace period — no ad.');
      return;
    }

    // Rule 1: every 5th track.
    if (_tracksCompletedThisSession % _adEveryNTracks == 0) {
      debugPrint('[SmartAd] 5-track milestone — emitting show.');
      _emitAd();
      return;
    }

    // Rule 2: 20+ minute session with no ad shown yet.
    if (_sessionStartedAt != null && _lastAdShownAt == null) {
      final sessionDuration = DateTime.now().difference(_sessionStartedAt!);
      if (sessionDuration >= _sessionAdThreshold) {
        debugPrint('[SmartAd] 20-minute session threshold — emitting show.');
        _emitAd();
      }
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _emitAd() {
    _lastAdShownAt = DateTime.now();
    _controller.add(AdEvent.show);
  }

  /// Dispose the stream controller. Call when the app is shutting down.
  void dispose() {
    _controller.close();
  }
}
