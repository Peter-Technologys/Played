import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/audio_handler.dart';
import 'core/services/appwrite_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_folder_service.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── BOOT ORDER (fastest possible cold start) ──────────────────────────
  // 1. Hive DB — must be ready before runApp so providers can read data.
  // 2. Settings — needed to override settingsProvider before runApp.
  // 3. runApp() — called as early as possible so the splash is visible.
  // 4. Everything else (AdMob, Appwrite, AudioService, Notifications,
  //    StorageFolder) runs AFTER runApp in the background — never blocks UI.
  // ─────────────────────────────────────────────────────────────────────

  // 1. Hive DB — only blocking init (providers need it immediately)
  await _initDatabase();

  // 2. Pre-load persisted settings
  final savedSettings = await AppSettings.load();

  // 3. Wire Flutter error handlers BEFORE runApp()
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[Error] ${details.summary}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    return true;
  };

  // 4. Run app immediately — splash is visible within ~100ms
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings)),
      ],
      child: const PlayedApp(),
    ),
  );

  // 5. Everything else runs in background AFTER UI is visible
  unawaited(_initBackground());
}

Future<void> _initDatabase() async {
  try {
    await PlayedDatabase.instance.init();
  } catch (e) {
    debugPrint('[PlayedDB] Init error: $e');
  }
}

/// All non-critical services — run after runApp so they never delay the UI.
Future<void> _initBackground() async {
  await Future.wait([
    _initNotifications(),
    _initAdMob(),
    _initAppwrite(),
    StorageFolderService.instance.ensureCreated(),
  ]);

  // AudioService must run after the widget tree is mounted
  try {
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
  } catch (e) {
    debugPrint('[AudioService] Init error: $e');
  }
}

Future<void> _initNotifications() async {
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[Notifications] Init error: $e');
  }
}

Future<void> _initAdMob() async {
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('[AdMob] Init error: $e');
  }
}

Future<void> _initAppwrite() async {
  try {
    AppwriteService.instance.init();
    await AppwriteService.instance.signInAnonymouslyIfNeeded();
  } catch (e) {
    debugPrint('[Appwrite] Init error: $e');
  }
}
