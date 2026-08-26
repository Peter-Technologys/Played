import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/services/audio_handler.dart';
import 'app/app.dart';
import 'core/database/otya_database.dart';
import 'core/services/notification_service.dart';
import 'core/services/media_notification_service.dart';
import 'core/services/phone_state_service.dart';
import 'core/services/pip_service.dart';
import 'core/services/playback_coordinator.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/crash_reporter.dart';
import 'core/services/fcm_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/storage_folder_service.dart';
import 'core/services/update_notification_service.dart';
import 'core/services/update_service.dart';
import 'core/services/device_service.dart';
import 'features/settings/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F1117),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.summary}\n${details.stack}');
    unawaited(CrashReporter.instance.report(
      details.exception,
      details.stack ?? StackTrace.empty,
    ));
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    unawaited(CrashReporter.instance.report(error, stack));
    return true;
  };

  await runZonedGuarded(() async {
    try {
      final audioHandler = await AudioService.init(
        builder: () => OtyaAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.otyaplayer.app.audio',
          androidNotificationChannelName: 'OTYA Player — Now Playing',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'drawable/ic_notification',
          notificationColor: Color(0xFF00E5FF),
          androidShowNotificationBadge: false,
          preloadArtwork: false,
        ),
      );
      AudioHandlerSingleton.instance.handler = audioHandler;
    } catch (e, st) {
      debugPrint('[AudioService] init failed: $e\n$st');
      unawaited(CrashReporter.instance.report(e, st));
    }

    final databaseReady = await _initDatabase();

    AppSettings savedSettings;
    try {
      savedSettings = await AppSettings.load();
    } catch (e, st) {
      debugPrint('[Settings] load failed: $e\n$st');
      unawaited(CrashReporter.instance.report(e, st));
      savedSettings = const AppSettings();
    }

    runApp(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings),
          ),
        ],
        child: const OtyaPlayerApp(),
      ),
    );

    unawaited(_initBackground(savedSettings, databaseReady));
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
    unawaited(CrashReporter.instance.report(error, stack));
  });
}

Future<bool> _initDatabase() async {
  try {
    await OtyaDatabase.instance.init();
    return true;
  } catch (e, st) {
    debugPrint('[OtyaDB] Init error: $e\n$st');
    unawaited(CrashReporter.instance.report(e, st));
    return false;
  }
}

Future<void> _initBackground(AppSettings savedSettings, bool databaseReady) async {
  await _safeBackground('notifications', _initNotifications);
  await _safeBackground('storage', StorageFolderService.instance.ensureCreated);
  await _safeBackground('connectivity', ConnectivityService.instance.init);
  await _safeBackground('cache', CacheService.instance.init);
  unawaited(_safeBackground('cache eviction', CacheService.instance.evictExpired));

  if (databaseReady) {
    unawaited(_safeBackground(
      'device registration',
      DeviceService.instance.registerIfNeeded,
    ));
  }

  unawaited(_safeBackground('update check', UpdateService.instance.checkAndNotify));

  PipService.listenForNativePause(
    () => PlaybackCoordinator.instance.activePlayer?.pause(),
    () => PlaybackCoordinator.instance.activePlayer?.play(),
  );

  unawaited(_safeBackground(
    'call handling',
    () => PhoneStateService.instance.setPauseDuringCalls(
      savedSettings.pauseDuringCalls,
    ),
  ));
  unawaited(_safeBackground('FCM', FcmService.instance.init));
  unawaited(_safeBackground('crash reporter', CrashReporter.instance.init));
}

Future<void> _safeBackground(String name, Future<void> Function() task) async {
  try {
    await task();
  } catch (e, st) {
    debugPrint('[Background:$name] Error: $e\n$st');
    unawaited(CrashReporter.instance.report(e, st));
  }
}

Future<void> _initNotifications() async {
  await _safeBackground('notification service', NotificationService.instance.init);
  await _safeBackground('update notifications', UpdateNotificationService.instance.init);
  await _safeBackground('media notifications', MediaNotificationService.instance.init);
  await _safeBackground('push notifications', PushNotificationService.instance.init);
}
