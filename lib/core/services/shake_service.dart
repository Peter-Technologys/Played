import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects a shake gesture using the accelerometer.
/// Call [start] with a callback — it fires every time a shake is detected.
/// Call [stop] to cancel the subscription.
class ShakeService {
  ShakeService._();
  static final ShakeService instance = ShakeService._();

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  // Threshold in m/s² — tune higher to require a harder shake
  static const double _threshold = 18.0;
  // Minimum ms between shake events to avoid double-firing
  static const int _cooldownMs = 1200;

  void start(VoidCallback onShake) {
    _sub?.cancel();
    _sub = accelerometerEventStream().listen((event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > _threshold) {
        final now = DateTime.now();
        if (now.difference(_lastShake).inMilliseconds > _cooldownMs) {
          _lastShake = now;
          onShake();
        }
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
