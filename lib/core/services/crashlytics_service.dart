import 'package:flutter/foundation.dart';

/// Local error logger — replaces Firebase Crashlytics.
/// Errors are printed to the debug console only. No remote calls.
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  Future<void> init() async {
    debugPrint('[ErrorLogger] Ready.');
  }

  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    debugPrint('[Error]${reason != null ? ' ($reason)' : ''} $error');
    if (stack != null) debugPrint(stack.toString());
  }

  void recordFlutterError(FlutterErrorDetails details) {
    debugPrint('[FlutterError] ${details.summary}');
  }

  void log(String message) => debugPrint('[Log] $message');

  void setKey(String key, Object value) =>
      debugPrint('[Key] $key = $value');
}
