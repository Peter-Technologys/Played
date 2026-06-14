import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/crashlytics_service.dart';
import 'core/services/notification_service.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── OFFLINE-FIRST BOOT ORDER ──────────────────────────────────────────
  // 1. Firebase runs entirely in the background — never blocks launch.
  //    The app works 100% offline from step 2 onward.
  // 2. Hive local DB — all media history, playlists, vault, seek positions.
  // 3. Local notifications — FFmpeg progress toasts.
  // 4. AdMob SDK registration — safe offline, just registers the SDK.
  // 5. Settings from SharedPreferences — loaded before runApp().
  // 6. Error handlers wired BEFORE runApp() so no crash goes unlogged.
  // ─────────────────────────────────────────────────────────────────────

  // 1. Firebase + Crashlytics — fire-and-forget, never blocks
  _initFirebaseInBackground();

  // 2. Hive local database — MUST succeed for the app to work offline
  try {
    await PlayedDatabase.instance.init();
  } catch (e, st) {
    debugPrint('[PlayedDB] Init error: $e');
    // Log to Crashlytics if it is already ready; otherwise just print
    CrashlyticsService.instance.recordError(e, st,
        reason: 'PlayedDatabase.init() failed at startup');
  }

  // 3. Local notifications
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[Notifications] Init error: $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'NotificationService.init() failed at startup');
  }

  // 4. AdMob SDK — safe offline, just registers the SDK
  try {
    await MobileAds.instance.initialize();
  } catch (e, st) {
    debugPrint('[AdMob] Init error: $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'MobileAds.initialize() failed at startup');
  }

  // 5. Pre-load persisted settings
  final savedSettings = await AppSettings.load();

  // 6. Wire Flutter + platform error handlers BEFORE runApp()
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    CrashlyticsService.instance.recordFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashlyticsService.instance.recordError(error, stack,
        reason: 'Uncaught platform error', fatal: true);
    return true;
  };

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings)),
      ],
      child: const PlayedApp(),
    ),
  );
}

/// Initialises Firebase, Crashlytics, and anonymous auth in the background.
///
/// This Future is intentionally NOT awaited — the app launches instantly
/// using local Hive + SharedPreferences. Firebase features (Firestore Pro
/// sync, Google Sign-In, Crashlytics) activate silently once the device
/// has internet. If the device is permanently offline they are never used.
void _initFirebaseInBackground() {
  Future(() async {
    try {
      await Firebase.initializeApp();

      // Disable Crashlytics in debug builds to avoid noise
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      // Hand Flutter errors to Crashlytics now that Firebase is ready
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Initialise our wrapper (sets user ID from FirebaseAuth)
      await CrashlyticsService.instance.init();

      // Silent anonymous sign-in — only runs when online
      await AuthService.instance.signInAnonymouslyIfNeeded();
    } catch (e) {
      // Offline or Firebase project not configured — app continues normally
      debugPrint('[Firebase] Background init failed (offline?): $e');
    }
  });
}
