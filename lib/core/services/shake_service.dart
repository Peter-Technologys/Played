import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';

/// Detects a shake gesture using the accelerometer.
class ShakeService {
  ShakeService._();
  static final ShakeService instance = ShakeService._();

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  static const double _threshold = 18.0;
  static const int _cooldownMs = 1200;

  void start(VoidCallback onShake) {
    _sub?.cancel();
    try {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        (event) {
          final magnitude = sqrt(
              event.x * event.x + event.y * event.y + event.z * event.z);
          if (magnitude > _threshold) {
            final now = DateTime.now();
            if (now.difference(_lastShake).inMilliseconds > _cooldownMs) {
              _lastShake = now;
              onShake();
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
