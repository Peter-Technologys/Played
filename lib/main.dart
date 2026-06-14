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

  // ── 1. Firebase + Crashlytics (background — never blocks launch) ──
  _initFirebaseInBackground();

  // ── 2. Local Hive database ────────────────────────────────────────
  try {
    await PlayedDatabase.instance.init();
  } catch (e, st) {
    // Database failure is non-fatal on first launch if vault key
    // generation races; log and continue — boxes will be re-opened.
    debugPrint('[PlayedDB] Init error (non-fatal): $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'PlayedDatabase.init() failed at startup');
  }

  // ── 3. Local notifications ────────────────────────────────────────
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[Notifications] Init error: $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'NotificationService.init() failed at startup');
  }

  // ── 4. Google Mobile Ads SDK (safe offline — just registers SDK) ──
  try {
    await MobileAds.instance.initialize();
  } catch (e, st) {
    debugPrint('[AdMob] Init error: $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'MobileAds.initialize() failed at startup');
  }

  // ── 5. Pre-load persisted settings ───────────────────────────────
  final savedSettings = await AppSettings.load();

  // ── 6. Wire Flutter framework errors → Crashlytics ───────────────
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    CrashlyticsService.instance.recordFlutterError(details);
  };

  // Catch async errors that escape the Flutter framework
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
/// Never blocks app launch — all features degrade gracefully offline.
void _initFirebaseInBackground() {
  Future(() async {
    try {
      await Firebase.initializeApp();

      // Enable Crashlytics crash collection (disable in debug if preferred)
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      // Pass Flutter errors to Crashlytics after Firebase is ready
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Initialise our service wrapper (sets user ID etc.)
      await CrashlyticsService.instance.init();

      // Silent anonymous sign-in
      await AuthService.instance.signInAnonymouslyIfNeeded();
    } catch (e) {
      debugPrint('[Firebase] Background init failed (offline?): $e');
    }
  });
}
