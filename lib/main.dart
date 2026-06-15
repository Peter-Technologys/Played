import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/audio_handler.dart';
import 'core/services/auth_service.dart';
import 'core/services/crashlytics_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_folder_service.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── OFFLINE-FIRST BOOT ORDER ──────────────────────────────────────────
  // 1. Firebase — fire-and-forget background init, never blocks launch.
  // 2. Hive DB + Notifications + AdMob — run in PARALLEL (not sequential)
  //    so startup is as fast as possible.
  // 3. Settings from SharedPreferences.
  // 4. Error handlers wired BEFORE runApp().
  // 5. runApp() called immediately — UI appears at once.
  // 6. AudioService.init() runs AFTER runApp() so it never blocks the UI.
  // ─────────────────────────────────────────────────────────────────────

  // 1. Firebase — fire-and-forget, never blocks
  _initFirebaseInBackground();

  // 2. Run Hive DB, Notifications, AdMob, and PLAYED folder IN PARALLEL
  await Future.wait([
    _initDatabase(),
    _initNotifications(),
    _initAdMob(),
    StorageFolderService.instance.ensureCreated(),
  ]);

  // 3. Pre-load persisted settings
  final savedSettings = await AppSettings.load();

  // 4. Wire Flutter + platform error handlers BEFORE runApp()
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    CrashlyticsService.instance.recordFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashlyticsService.instance.recordError(error, stack,
        reason: 'Uncaught platform error', fatal: true);
    return true;
  };

  // 5. Run app immediately — UI is visible before AudioService starts
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings)),
      ],
      child: const PlayedApp(),
    ),
  );

  // 6. Initialise audio_service AFTER runApp so the loading screen
  //    disappears instantly. Creates the foreground media service that
  //    powers the notification media player on Android.
  globalAudioHandler = await AudioService.init(
    builder: () => PlayedAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.petersmart.played.audio',
      androidNotificationChannelName: 'PLAYED Media',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: Color(0xFF00D4FF),
    ),
  );
}

Future<void> _initDatabase() async {
  try {
    await PlayedDatabase.instance.init();
  } catch (e, st) {
    debugPrint('[PlayedDB] Init error: $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'PlayedDatabase.init() failed at startup');
  }
}

Future<void> _initNotifications() async {
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[Notifications] Init error: $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'NotificationService.init() failed at startup');
  }
}

Future<void> _initAdMob() async {
  try {
    await MobileAds.instance.initialize();
  } catch (e, st) {
    debugPrint('[AdMob] Init error: $e');
    CrashlyticsService.instance.recordError(e, st,
        reason: 'MobileAds.initialize() failed at startup');
  }
}

/// Initialises Firebase, Crashlytics, and anonymous auth in the background.
/// This Future is intentionally NOT awaited — the app launches instantly.
void _initFirebaseInBackground() {
  Future(() async {
    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      await CrashlyticsService.instance.init();
      await AuthService.instance.signInAnonymouslyIfNeeded();
    } catch (e) {
      debugPrint('[Firebase] Background init failed (offline?): $e');
    }
  });
}
