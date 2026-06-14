import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Crashlytics.
///
/// Usage:
///   CrashlyticsService.instance.recordError(e, st, reason: 'context');
///   CrashlyticsService.instance.log('User tapped play');
///
/// All methods are no-ops when Crashlytics is not yet initialised
/// (e.g. during offline startup) — they never throw.
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  bool _ready = false;

  FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  /// Call once after Firebase.initializeApp() completes.
  /// Sets the current user ID so crashes are grouped by user in the console.
  Future<void> init() async {
    try {
      _ready = true;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _c.setUserIdentifier(uid);

      // Listen for auth changes so the UID stays current after Google sign-in
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (!_ready) return;
        try {
          await _c.setUserIdentifier(user?.uid ?? 'anonymous');
        } catch (_) {}
      });

      debugPrint('[Crashlytics] Initialised. Collection enabled: '
          '${_c.isCrashlyticsCollectionEnabled}');
    } catch (e) {
      debugPrint('[Crashlytics] Init failed: $e');
    }
  }

  /// Records a non-fatal error with optional [reason] context string.
  /// Pass [fatal: true] for errors that caused the app to terminate.
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

  /// Records a Flutter framework error (from FlutterError.onError).
  void recordFlutterError(FlutterErrorDetails details) {
    if (!_ready) return;
    try {
      _c.recordFlutterError(details);
    } catch (_) {}
  }

  /// Adds a breadcrumb log line visible in the Crashlytics console
  /// alongside any subsequent crash report.
  void log(String message) {
    if (!_ready) return;
    try {
      _c.log(message);
    } catch (_) {}
  }

  /// Sets a custom key-value pair visible in crash reports.
  void setKey(String key, Object value) {
    if (!_ready) return;
    try {
      _c.setCustomKey(key, value);
    } catch (_) {}
  }
}
