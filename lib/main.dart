import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app/app.dart';
import 'core/database/otya_database.dart';
import 'core/services/audio_handler.dart';
import 'core/services/cache_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/crash_reporter.dart';
import 'core/services/device_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/media_notification_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/phone_state_service.dart';
import 'core/services/pip_service.dart';
import 'core/services/playback_coordinator.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/storage_folder_service.dart';
import 'core/services/update_notification_service.dart';
import 'core/services/update_service.dart';
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
    systemNavigationBarColor: Color(0xFF0A0A0F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.summary}\n${details.stack}');
    CrashReporter.instance.report(
      details.exception,
      details.stack ?? StackTrace.empty,
    );
    if (kDebugMode) {
      _showCrashOverlay('Flutter Error', '${details.summary}\n\n${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    CrashReporter.instance.report(error, stack);
    if (kDebugMode) {
      _showCrashOverlay('Platform Error', '$error\n\n$stack');
    }
    return true;
  };

  try {
    final audioHandler = await AudioService.init(
      builder: () => OtyaAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.otyaplayer.app.audio',
        androidNotificationChannelName: 'OTYA Player — Now Playing',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'drawable/ic_notification',
        notificationColor: const Color(0xFF8B5CF6),
        androidShowNotificationBadge: false,
        preloadArtwork: true,
      ),
    );
    AudioHandlerSingleton.instance.handler = audioHandler;
  } catch (e, st) {
    debugPrint('[AudioService] init failed: $e\n$st');
    CrashReporter.instance.report(e, st);
  }

  await runZonedGuarded(() async {
    var databaseReady = false;
    try {
      databaseReady = await _initDatabase();
    } catch (e, st) {
      debugPrint('[Database] init failed: $e\n$st');
      CrashReporter.instance.report(e, st);
    }

    AppSettings savedSettings;
    try {
      savedSettings = await AppSettings.load();
    } catch (e, st) {
      debugPrint('[Settings] load failed: $e\n$st');
      CrashReporter.instance.report(e, st);
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
    CrashReporter.instance.report(error, stack);
    if (kDebugMode) {
      _showCrashOverlay('Startup Crash', '$error\n\n$stack');
    }
  });
}

void _showCrashOverlay(String title, String details) {
  if (!kDebugMode) return;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A0000),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bug_report, color: Color(0xFFFF4444), size: 40),
                const SizedBox(height: 8),
                Text(
                  'OTYA CRASH: $title',
                  style: const TextStyle(
                    color: Color(0xFFFF4444),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A0000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    details,
                    style: const TextStyle(
                      color: Color(0xFFFFCCCC),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This diagnostic screen is debug-only.',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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

  unawaited(_safeBackground(
    'update check',
    UpdateService.instance.checkAndNotify,
  ));

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
  await _safeBackground('notification service', NotificationService.instance.init);
  await _safeBackground(
    'update notifications',
    UpdateNotificationService.instance.init,
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
