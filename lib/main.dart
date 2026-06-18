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

  // 4. AudioService — init BEFORE runApp so it is ready the moment
  //    the user taps a song. Moving this to background was the #1 cause
  //    of "nothing plays" on first tap.
  await _initAudioService();

  // 5. Pre-load persisted settings
  final savedSettings = await AppSettings.load();

  // 6. Run app
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings)),
      ],
      child: const OtyaPlayerApp(),
    ),
  );

  // 7. Everything else in background
  unawaited(_initBackground());
}

Future<void> _initDatabase() async {
  try {
    await PlayedDatabase.instance.init();
  } catch (e, st) {
    debugPrint('[PlayedDB] Init error: $e\n$st');
    try {
      await PlayedDatabase.instance.deleteAndReinit();
    } catch (_) {}
  }
}

Future<void> _initAudioService() async {
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
    debugPrint('[AudioService] Ready.');
  } catch (e) {
    debugPrint('[AudioService] Init error: $e');
  }
}

Future<void> _initBackground() async {
  await Future.wait([
    _initNotifications(),
    _initAdMob(),
    _initAppwrite(),
    StorageFolderService.instance.ensureCreated(),
  ]);
  // AudioService is already initialized before runApp — nothing to do here.
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
  } catch (e) {
    debugPrint('[Appwrite] Init error: $e');
  }
}
