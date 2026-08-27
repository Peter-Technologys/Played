// lib/core/services/sleep_detection_service.dart
//
// SleepDetectionService — tracks user interaction timestamps and emits a
// callback when no interaction has occurred for a configurable timeout.

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Singleton that detects user inactivity and fires [onSleepDetected].
///
/// Uses a single deadline timer instead of polling every 30 seconds. This keeps
/// the service effectively idle while the user is listening, reducing wakeups,
/// battery work and timer churn on low-end devices.
class SleepDetectionService {
  SleepDetectionService._();
  static final SleepDetectionService instance = SleepDetectionService._();

  VoidCallback? onSleepDetected;

  Duration _timeout = const Duration(minutes: 30);
  DateTime? _lastInteractionAt;
  Timer? _timer;
  bool _running = false;
  int _generation = 0;

  /// Start monitoring for inactivity. Calling [start] again safely replaces
  /// the previous deadline.
  void start([Duration timeout = const Duration(minutes: 30)]) {
    if (timeout <= Duration.zero) {
      stop();
      return;
    }
    _timeout = timeout;
    _running = true;
    _lastInteractionAt = DateTime.now();
    _scheduleDeadline();
    if (kDebugMode) {
      debugPrint('[SleepDetection] Started — timeout: ${_timeout.inMinutes}m');
    }
  }

  /// Stop monitoring and invalidate any callback already queued by an older
  /// timer generation.
  void stop() {
    _running = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    if (kDebugMode) debugPrint('[SleepDetection] Stopped.');
  }

  /// Record user interaction and move the deadline forward. This is cheap and
  /// safe to call for taps, seeks and skips.
  void recordInteraction() {
    if (!_running) return;
    _lastInteractionAt = DateTime.now();
    _scheduleDeadline();
  }

  bool get isRunning => _running;

  Duration get timeSinceLastInteraction {
    final last = _lastInteractionAt;
    if (last == null) return Duration.zero;
    final elapsed = DateTime.now().difference(last);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  void _scheduleDeadline() {
    _timer?.cancel();
    if (!_running) return;

    final generation = ++_generation;
    final remaining = _timeout - timeSinceLastInteraction;
    if (remaining <= Duration.zero) {
      scheduleMicrotask(() => _fireIfCurrent(generation));
      return;
    }
    _timer = Timer(remaining, () => _fireIfCurrent(generation));
  }

  void _fireIfCurrent(int generation) {
    if (!_running || generation != _generation) return;

    // Timers may wake slightly early on some devices. Recalculate rather than
    // firing prematurely.
    final remaining = _timeout - timeSinceLastInteraction;
    if (remaining > Duration.zero) {
      _timer = Timer(remaining, () => _fireIfCurrent(generation));
      return;
    }

    final callback = onSleepDetected;
    stop();
    try {
      callback?.call();
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'OTYA sleep detection',
        context: ErrorDescription('while invoking the inactivity callback'),
      ));
    }
  }
}
