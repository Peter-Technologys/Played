import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app/app.dart';
import 'core/database/otya_database.dart';
import 'core/services/audio_handler.dart';
import 'core/services/audio_session_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/crash_reporter.dart';
import 'core/services/device_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/firebase_platform_service.dart';
import 'core/services/media_notification_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pip_service.dart';
import 'core/services/playback_coordinator.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/storage_folder_service.dart';
import 'core/services/update_service.dart';
import 'features/settings/settings_provider.dart';

Future<void> main() async {
  // Flutter records the zone in which the binding is initialized and requires
  // runApp to execute in that same zone. Keeping both inside one guarded zone
  // prevents the startup "Zone mismatch" loop seen in device bugreports.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Install one crash pipeline before the first frame. The old startup code
    // installed a second pair of Flutter/platform handlers and CrashReporter
    // later chained back into them, which could upload the same failure twice.
    await CrashReporter.instance.init();

    final settingsNotifier = SettingsNotifier(const AppSettings());

    // First paint must not wait on SharedPreferences, SQLite, MediaKit,
    // AudioService, Firebase or any other plugin-backed service. Render Otya
    // immediately with safe local defaults, then hydrate after the first frame.
    runApp(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => settingsNotifier),
        ],
        child: const OtyaPlayerApp(),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapAfterFirstFrame(settingsNotifier));
    });
  }, (error, stack) {
    // Never call runApp from a zone error callback. Replacing the root widget
    // from here can recursively trigger the same startup error and leave the
    // Android splash visible indefinitely. Log/report instead; the app's normal
    // UI remains the only root widget tree.
    debugPrint('[ZoneError] $error\n$stack');
    CrashReporter.instance.report(error, stack);
  });
}

Future<void> _bootstrapAfterFirstFrame(SettingsNotifier settingsNotifier) async {
  var savedSettings = const AppSettings();
  try {
    savedSettings = await AppSettings.load();
    settingsNotifier.hydrate(savedSettings);
  } catch (e, st) {
    debugPrint('[Settings] load failed: $e\n$st');
    CrashReporter.instance.report(e, st);
  }

  var databaseReady = false;
  try {
    databaseReady = await _initDatabase();
  } catch (e, st) {
    debugPrint('[Database] init failed: $e\n$st');
    CrashReporter.instance.report(e, st);
  }

  await _initBackground(savedSettings, databaseReady);
}

Future<bool> _initDatabase() async {
  try {
    await OtyaDatabase.instance.init();
    return true;
  } catch (e, st) {
    debugPrint('[OtyaDB] Init error: $e\n$st');
    CrashReporter.instance.report(e, st);
    return false;
  }
}

Future<void> _initBackground(
  AppSettings savedSettings,
  bool databaseReady,
) async {
  // Playback platform comes first so a song started immediately after launch
  // gets a real Android MediaSession/foreground-service notification.
  await _safeBackground('playback platform', _initPlaybackPlatform);
  await _safeBackground('notifications', _initNotifications);
  await _safeBackground('storage', StorageFolderService.instance.ensureCreated);
  await _safeBackground('connectivity', ConnectivityService.instance.init);
  await _safeBackground('cache', CacheService.instance.init);

  unawaited(_safeBackground('cache eviction', CacheService.instance.evictExpired));

  if (databaseReady) {
    unawaited(
      _safeBackground('device registration', DeviceService.instance.registerIfNeeded),
    );
  }

  unawaited(
    _safeBackground('update check', UpdateService.instance.checkAndNotify),
  );

  PipService.listenForNativePause(
    () => PlaybackCoordinator.instance.activePlayer?.pause(),
    () => PlaybackCoordinator.instance.activePlayer?.play(),
  );

  await _safeBackground(
    'audio session',
    () => AudioSessionService.instance.init(
      pauseDuringCalls: savedSettings.pauseDuringCalls,
    ),
  );

  await _safeBackground(
    'Firebase platform',
    FirebasePlatformService.instance.initOptionalServices,
  );
  unawaited(_safeBackground('FCM', FcmService.instance.init));
}

Future<void> _initPlaybackPlatform() async {
  MediaKit.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));

  final audioHandler = await AudioService.init(
    builder: () => OtyaAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.otyaplayer.app.audio',
      androidNotificationChannelName: 'Otya — Now Playing',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'drawable/ic_notification',
      notificationColor: const Color(0xFF2979FF),
      androidShowNotificationBadge: false,
      preloadArtwork: true,
    ),
  );
  AudioHandlerSingleton.instance.handler = audioHandler;
}

Future<void> _safeBackground(
  String name,
  Future<void> Function() task,
) async {
  try {
    await task();
  } catch (e, st) {
    debugPrint('[Background:$name] Error: $e\n$st');
    CrashReporter.instance.report(e, st);
  }
}

Future<void> _initNotifications() async {
  await _safeBackground(
    'notification service',
    NotificationService.instance.init,
  );
  await _safeBackground(
    'media notifications',
    MediaNotificationService.instance.init,
  );
  await _safeBackground(
    'push notifications',
    PushNotificationService.instance.init,
  );
}
