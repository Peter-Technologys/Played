import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Crashlytics.
///
/// All methods are no-ops when [_ready] is false — i.e. before
/// Firebase.initializeApp() has completed in the background.
/// The app never crashes at startup due to Crashlytics not being ready,
/// including on sideloaded APKs or offline devices.
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  bool _ready = false;

  FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  /// Call once after Firebase.initializeApp() completes.
  Future<void> init() async {
    try {
      _ready = true;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _c.setUserIdentifier(uid);

      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (!_ready) return;
        try {
          await _c.setUserIdentifier(user?.uid ?? 'anonymous');
        } catch (_) {}
      });

      debugPrint('[Crashlytics] Ready. '
          'Collection: ${_c.isCrashlyticsCollectionEnabled}');
    } catch (e) {
      _ready = false;
      debugPrint('[Crashlytics] Init failed (offline/no config?): $e');
    }
  }

  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (!_ready) {
      debugPrint('[Crashlytics] (not ready) $reason: $error');
      return;
    }
    try {
      _c.recordError(error, stack, reason: reason, fatal: fatal);
    } catch (_) {}
  }

  void recordFlutterError(FlutterErrorDetails details) {
    if (!_ready) {
      debugPrint('[Crashlytics] (not ready): ${details.summary}');
      return;
    }
    try {
      _c.recordFlutterError(details);
    } catch (_) {}
  }

  void log(String message) {
    if (!_ready) return;
    try {
      _c.log(message);
    } catch (_) {}
  }

  void setKey(String key, Object value) {
    if (!_ready) return;
    try {
      _c.setCustomKey(key, value);
    } catch (_) {}
  }
}
