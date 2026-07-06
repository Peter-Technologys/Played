import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ADS DISABLED — re-enable when listed on Play Store
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/audio_handler.dart';
import 'core/services/appwrite_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_folder_service.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.summary}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    return true;
  };

  // ── Fast path: only the minimum before runApp ─────────────────────
  // Target: first frame < 200 ms on mid-range Android.
  //
  // 1. Hive DB — must be open before providers read from it (~30 ms).
  await _initDatabase();

  // 2. Settings — SharedPreferences read (~5 ms).
  final savedSettings = await AppSettings.load();

  // 3. runApp IMMEDIATELY — do NOT await AudioService here.
  //    AudioService.init() binds to an Android foreground service which
  //    takes 300–800 ms. Blocking runApp on it means the user stares at
  //    the splash for that entire time before seeing any UI.
  //    AudioPlayerNotifier retries up to 4 s if the handler is null.
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings)),
      ],
      child: const OtyaPlayerApp(),
    ),
  );

  // 4. Everything else after the first frame is on screen.
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

Future<void> _initBackground() async {
  // AudioService, notifications, Appwrite all run in parallel after
  // the first frame so they never delay what the user sees.
  await Future.wait([
    _initAudioService(),
    _initNotifications(),
    _initAppwrite(),
    StorageFolderService.instance.ensureCreated(),
  ]);
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

Future<void> _initNotifications() async {
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[Notifications] Init error: $e');
  }
}

// ADS DISABLED — re-enable when listed on Play Store
// Future<void> _initAdMob() async { ... }

Future<void> _initAppwrite() async {
  try {
    AppwriteService.instance.init();
  } catch (e) {
    debugPrint('[Appwrite] Init error: $e');
  }
}
