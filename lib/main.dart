import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app/app.dart'; // OtyaPlayerApp
import 'core/database/played_database.dart';
import 'core/services/audio_handler.dart';
import 'core/services/appwrite_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_folder_service.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wire error handlers first — catch anything that happens during init
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.summary}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    return true; // prevent crash
  };

  // 1. Hive DB — only blocking init (providers need it immediately)
  await _initDatabase();

  // 2. Pre-load persisted settings
  final savedSettings = await AppSettings.load();

  // 3. Run app immediately — splash visible within ~100ms
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings)),
      ],
      child: const OtyaPlayerApp(),
    ),
  );

  // 4. Everything else in background — never blocks UI
  unawaited(_initBackground());
}

Future<void> _initDatabase() async {
  try {
    await PlayedDatabase.instance.init();
  } catch (e, st) {
    debugPrint('[PlayedDB] Init error: $e\n$st');
    // If Hive is corrupted, delete and retry with fresh boxes
    try {
      await PlayedDatabase.instance.deleteAndReinit();
    } catch (_) {}
  }
}

Future<void> _initBackground() async {
  await Future.wait([
    _initNotifications(),
    _initAdMob(),
    _initAppwrite(),
    StorageFolderService.instance.ensureCreated(),
  ]);

  // AudioService must run after the widget tree is mounted
  try {
    globalAudioHandler ??= await AudioService.init(
      builder: () => PlayedAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.otyaplayer.app.audio',
        androidNotificationChannelName: 'OTYA Player Media',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        notificationColor: Color(0xFF8A2BE2),
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
    // Fire-and-forget — never block startup on network
    unawaited(
      AppwriteService.instance.signInAnonymouslyIfNeeded()
          .timeout(const Duration(seconds: 10))
          .catchError((e) {
        debugPrint('[Appwrite] Background init failed (offline?): $e');
      }),
    );
  } catch (e) {
    debugPrint('[Appwrite] Init error: $e');
  }
}
