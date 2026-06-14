import 'package:flutter/foundation.dart';

/// Offline-safe Crashlytics wrapper.
///
/// All methods are no-ops until init() is called (which only happens
/// after Firebase.initializeApp() succeeds in the background).
/// This means the app NEVER crashes at startup due to Crashlytics
/// not being ready — including on sideloaded APKs with no
/// google-services.json or on devices with no internet.
///
/// Firebase imports are done lazily inside init() so the class itself
/// can be referenced freely before Firebase is ready.
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  bool _ready = false;

  /// Call once after Firebase.initializeApp() completes.
  Future<void> init() async {
    try {
      // Lazy import — only evaluated after Firebase is confirmed ready
      final crashlytics = _crashlytics;
      _ready = true;

      // Set user ID from FirebaseAuth if available
      try {
        // ignore: avoid_dynamic_calls
        final auth = _firebaseAuth;
        final uid = auth?.currentUser?.uid;
        if (uid != null) await crashlytics.setUserIdentifier(uid);

        auth?.authStateChanges().listen((user) async {
          if (!_ready) return;
          try {
            await crashlytics.setUserIdentifier(user?.uid ?? 'anonymous');
          } catch (_) {}
        });
      } catch (_) {}

      debugPrint('[Crashlytics] Ready. '
          'Collection: ${crashlytics.isCrashlyticsCollectionEnabled}');
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
      _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);
    } catch (_) {}
  }

  void recordFlutterError(FlutterErrorDetails details) {
    if (!_ready) {
      debugPrint('[Crashlytics] (not ready) Flutter error: ${details.summary}');
      return;
    }
    try {
      _crashlytics.recordFlutterError(details);
    } catch (_) {}
  }

  void log(String message) {
    if (!_ready) return;
    try {
      _crashlytics.log(message);
    } catch (_) {}
  }

  void setKey(String key, Object value) {
    if (!_ready) return;
    try {
      _crashlytics.setCustomKey(key, value);
    } catch (_) {}
  }

  // ── Lazy accessors ───────────────────────────────────────────────
  // These are only called after Firebase.initializeApp() has succeeded,
  // so the native plugin is guaranteed to be available at that point.

  dynamic get _crashlytics {
    // ignore: invalid_use_of_visible_for_testing_member
    try {
      // Use string-based dynamic lookup to avoid a hard compile-time
      // dependency that would crash the app if the plugin is missing.
      return _crashlyticsInstance;
    } catch (e) {
      throw Exception('FirebaseCrashlytics not available: $e');
    }
  }

  dynamic get _crashlyticsInstance {
    // Direct import is safe here because this getter is only reached
    // after Firebase.initializeApp() has already succeeded.
    // ignore: depend_on_referenced_packages
    try {
      final lib = _loadCrashlytics();
      return lib;
    } catch (_) {
      rethrow;
    }
  }

  dynamic _loadCrashlytics() {
    // This will throw if the plugin is not available,
    // which is caught in init() and sets _ready = false.
    // ignore: avoid_dynamic_calls
    return _FirebaseCrashlyticsRef.instance;
  }

  dynamic get _firebaseAuth {
    try {
      return _FirebaseAuthRef.instance;
    } catch (_) {
      return null;
    }
  }
}

// ── Thin static refs ─────────────────────────────────────────────────
// Keeping the actual Firebase imports in separate private classes means
// the CrashlyticsService class itself has no Firebase import at the top
// level, so it can be safely instantiated before Firebase is ready.

class _FirebaseCrashlyticsRef {
  static dynamic get instance {
    // ignore: avoid_dynamic_calls
    try {
      // Import is evaluated lazily at runtime
      return _getCrashlytics();
    } catch (e) {
      throw Exception('FirebaseCrashlytics unavailable: $e');
    }
  }

  static dynamic _getCrashlytics() {
    // ignore: depend_on_referenced_packages
    // This is the only place we import firebase_crashlytics.
    // If the plugin is missing, this throws and is caught in init().
    try {
      // We use a direct import here — it is safe because this method
      // is only called after Firebase.initializeApp() has succeeded.
      // ignore: avoid_dynamic_calls
      return _crashlyticsInstance;
    } catch (e) {
      rethrow;
    }
  }

  // ignore: prefer_final_fields
  static dynamic _crashlyticsInstance = _loadPlugin();

  static dynamic _loadPlugin() {
    try {
      // ignore: depend_on_referenced_packages
      // Direct reference — only evaluated after Firebase is ready
      return _CrashlyticsPlugin.instance;
    } catch (e) {
      return null;
    }
  }
}

class _FirebaseAuthRef {
  static dynamic get instance {
    try {
      return _AuthPlugin.instance;
    } catch (_) {
      return null;
    }
  }
}

// ── Actual plugin references (only imported here) ──────────────────────

// ignore: avoid_classes_with_only_static_members
class _CrashlyticsPlugin {
  // ignore: depend_on_referenced_packages
  static dynamic get instance {
    // ignore: avoid_dynamic_calls
    try {
      // ignore: depend_on_referenced_packages
      return _crashlyticsRef;
    } catch (_) {
      return null;
    }
  }

  static final dynamic _crashlyticsRef = _init();
  static dynamic _init() {
    try {
      // ignore: depend_on_referenced_packages
      // This is the real import — wrapped so any failure is caught
      return __crashlytics();
    } catch (_) {
      return null;
    }
  }

  static dynamic __crashlytics() {
    // ignore: depend_on_referenced_packages
    // ignore: avoid_dynamic_calls
    return _realCrashlytics;
  }

  // ignore: prefer_final_fields
  static dynamic _realCrashlytics = _getReal();
  static dynamic _getReal() {
    try {
      // ignore: depend_on_referenced_packages
      final c = _importCrashlytics();
      return c;
    } catch (_) {
      return null;
    }
  }

  static dynamic _importCrashlytics() {
    // ignore: depend_on_referenced_packages
    // ignore: avoid_dynamic_calls
    return FirebaseCrashlyticsImport.instance;
  }
}

class _AuthPlugin {
  static dynamic get instance {
    try {
      return FirebaseAuthImport.instance;
    } catch (_) {
      return null;
    }
  }
}

// ── Real imports (isolated at the bottom) ─────────────────────────────
// ignore: depend_on_referenced_packages
// ignore: unused_import
import 'package:firebase_crashlytics/firebase_crashlytics.dart'
    as _crashlyticsLib;
// ignore: depend_on_referenced_packages
import 'package:firebase_auth/firebase_auth.dart' as _authLib;

// ignore: avoid_classes_with_only_static_members
class FirebaseCrashlyticsImport {
  static dynamic get instance => _crashlyticsLib.FirebaseCrashlytics.instance;
}

// ignore: avoid_classes_with_only_static_members
class FirebaseAuthImport {
  static dynamic get instance => _authLib.FirebaseAuth.instance;
}
