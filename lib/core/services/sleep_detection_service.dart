// lib/core/services/sleep_detection_service.dart
//
// SleepDetectionService — tracks user interaction timestamps and emits a
// callback when no interaction has occurred for a configurable timeout.
//
// Interactions tracked:
//   - recordInteraction() — call on any tap, seek, or skip event.
//
// Usage:
//   SleepDetectionService.instance.onSleepDetected = () { /* pause playback */ };
//   SleepDetectionService.instance.start(const Duration(minutes: 30));
//   // ... on user tap:
//   SleepDetectionService.instance.recordInteraction();
//   // ... when done:
//   SleepDetectionService.instance.stop();

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Singleton that detects user inactivity and fires [onSleepDetected].
class SleepDetectionService {
  SleepDetectionService._();
  static final SleepDetectionService instance = SleepDetectionService._();

  // ── State ─────────────────────────────────────────────────────────────────

  /// Called when the inactivity timeout elapses with no recorded interaction.
  /// Set this before calling [start].
  VoidCallback? onSleepDetected;

  Duration _timeout = const Duration(minutes: 30);
  DateTime? _lastInteractionAt;
  Timer? _timer;
  bool _running = false;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start monitoring for inactivity.
  ///
  /// [timeout] — how long without interaction before [onSleepDetected] fires.
  /// Defaults to 30 minutes. Calling [start] while already running resets the
  /// timer with the new timeout.
  void start([Duration timeout = const Duration(minutes: 30)]) {
    _timeout = timeout;
    _running = true;
    _lastInteractionAt = DateTime.now();
    _scheduleCheck();
    debugPrint('[SleepDetection] Started — timeout: ${_timeout.inMinutes}m');
  }

  /// Stop monitoring. Cancels any pending timer.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('[SleepDetection] Stopped.');
  }

  /// Record a user interaction (tap, seek, skip, etc.).
  /// Resets the inactivity countdown.
  void recordInteraction() {
    _lastInteractionAt = DateTime.now();
    if (kDebugMode) debugPrint('[SleepDetection] Interaction recorded at $_lastInteractionAt');
  }

  /// Whether the service is currently running.
  bool get isRunning => _running;

  /// Time elapsed since the last recorded interaction.
  /// Returns [Duration.zero] if no interaction has been recorded yet.
  Duration get timeSinceLastInteraction {
    if (_lastInteractionAt == null) return Duration.zero;
    return DateTime.now().difference(_lastInteractionAt!);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _scheduleCheck() {
    _timer?.cancel();
    if (!_running) return;

    // Check every 30 seconds for responsiveness; fire when elapsed ≥ timeout.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  void _check() {
    if (!_running) return;

    final elapsed = timeSinceLastInteraction;
    if (kDebugMode) {
      debugPrint('[SleepDetection] Inactivity check — elapsed: ${elapsed.inSeconds}s / timeout: ${_timeout.inSeconds}s');
    }

    if (elapsed >= _timeout) {
      debugPrint('[SleepDetection] Sleep detected — firing callback.');
      stop();
      onSleepDetected?.call();
    }
  }
}
