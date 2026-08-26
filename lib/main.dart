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
import 'core/services/device_service.dart';
import 'core/services/notification_service.dart';
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
// MediaKit must be initialized before any Player is created.
MediaKit.ensureInitialized();

// Do not lock the entire application to portrait: video playback and
// responsive layouts need to support landscape and modern Android devices.
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
  CrashReporter.instance.report(
    details.exception,
    details.stack ?? StackTrace.empty,
  );
};
PlatformDispatcher.instance.onError = (error, stack) {
  debugPrint('[PlatformError] $error\n$stack');
  unawaited(CrashReporter.instance.report(error, stack));
  if (kDebugMode) {
    _showCrashOverlay('Platform Error', '$error\n\n$stack');
  }
  return true;
};

await runZonedGuarded(() async {
  // Keep only lightweight, recoverable storage initialization on the
  // critical startup path. AudioService and network/background work are
  // initialized separately so a native service failure cannot prevent
  // the app UI from opening.
  bool databaseReady = false;

  try {
    databaseReady = await _initDatabase();
  } catch (e, st) {
    debugPrint('[Database] init failed: $e\n$st');
    unawaited(CrashReporter.instance.report(e, st));
  }

  AppSettings savedSettings;
  try {
    savedSettings = await AppSettings.load();
  } catch (e, st) {
    debugPrint('[Settings] load failed: $e\n$st');
    unawaited(CrashReporter.instance.report(e, st));
    savedSettings = AppSettings.defaults();
  }

  // Continue startup even when an optional subsystem fails.
  unawaited(_initBackground(savedSettings, databaseReady));

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
} catch (e, st) {
  // A catastrophic startup dependency must still produce a recoverable UI
  // rather than a blank/crashed process. Database data is never deleted here.
  debugPrint('[Startup] $e\n$st');
  unawaited(CrashReporter.instance.report(e, st));
  runApp(const ProviderScope(child: OtyaPlayerApp()));
  if (kDebugMode) _showCrashOverlay('Startup Error', '$e\n\n$st');
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
                  style: TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 12,
                  ),
                ),
      ),
    );
    AudioHandlerSingleton.instance.handler = audioHandler;
  } catch (e, st) {
    // Playback remains available through media_kit even if the optional
    // background media service cannot be started on a particular device.
    debugPrint('[AudioService] deferred init failed: $e\n$st');
    CrashReporter.instance.report(e, st);
  }
}

Future<bool> _initDatabase() async {
  try {
    await OtyaDatabase.instance.init();
    return true;
  } catch (e, st) {
    // Do not wipe the user's entire database automatically. A destructive
    // reset during startup can turn a recoverable storage problem into data
    // loss and does not fix every possible Hive initialization failure.
    debugPrint('[OtyaDB] Init error: $e\n$st');
    unawaited(CrashReporter.instance.report(e, st));
    // Never destroy a user's database as automatic crash recovery.
    return false;
  }
}

Future<void> _initBackground(
  AppSettings savedSettings,
  bool databaseReady,
) async {
  // Keep native audio initialization independent from network/background
  // services so a failure there cannot prevent the rest of startup.
  unawaited(_initAudioService());

  await _safeBackground('notifications', _initNotifications);
  await _safeBackground(
    'storage',
    StorageFolderService.instance.ensureCreated,
  );
  await _safeBackground(
    'connectivity',
    ConnectivityService.instance.init,
  );
  await _safeBackground(
    'cache',
    CacheService.instance.init,
  );

  unawaited(
    _safeBackground(
      'cache eviction',
      CacheService.instance.evictExpired,
    ),
  );

  if (databaseReady) {
    unawaited(
      _safeBackground(
        'device registration',
        DeviceService.instance.registerIfNeeded,
      ),
    );
  }

  unawaited(
    _safeBackground(
      'update check',
      UpdateService.instance.checkAndNotify,
    ),
  );

  PipService.listenForNativePause(
    () => PlaybackCoordinator.instance.activePlayer?.pause(),
    () => PlaybackCoordinator.instance.activePlayer?.play(),
  );


}

Future<void> _initNotifications() async {
  await NotificationService.instance.init();
}

void _initPushNotifications() {
  try {
    PushNotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[PushNotifications] init failed: $e\n$st');
  }
}
void _initPhoneState() {
  try {
    PhoneStateService.instance.initialize();
  } catch (e, st) {
    debugPrint('[PhoneState] init failed: $e\n$st');
  }
}

void _initFcm() {
  try {
    FcmService.instance.initialize();
  } catch (e, st) {
    debugPrint('[FCM] init failed: $e\n$st');
  }
}

void _initUpdateNotifications(AppSettings settings) {
  try {
    UpdateNotificationService.instance.initialize(settings);
  } catch (e, st) {
    debugPrint('[UpdateNotifications] init failed: $e\n$st');
  }
}
