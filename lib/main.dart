import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:workmanager/workmanager.dart';
import 'core/services/audio_handler.dart';
import 'app/app.dart';
import 'core/database/otya_database.dart';
import 'core/services/cloudflare_service.dart';
import 'core/services/device_service.dart';
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
import 'features/settings/settings_provider.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'otya_update_check') {
      await UpdateService.instance.checkAndNotify();
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit MUST be initialized before runApp — without this, video
  // playback silently fails on some devices (native libs not loaded).
  MediaKit.ensureInitialized();

  // Lock to portrait on startup; video player overrides to landscape.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar, light icons — applied once here.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F1117),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.summary}\n${details.stack}');
    if (kDebugMode) _showCrashOverlay('Flutter Error', '${details.summary}\n\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    if (kDebugMode) _showCrashOverlay('Platform Error', '$error\n\n$stack');
    return true;
  };

  // Initialise audio_service before runApp so the foreground service is ready
  // before any Player is created.
  // Wrapped in try/catch so a failure here does not kill the app — audio
  // simply won't be available, but the rest of the app can still launch.
  try {
    final audioHandler = await AudioService.init(
      builder: () => OtyaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.otyaplayer.app.audio',
        androidNotificationChannelName: 'OTYA Player \u2014 Now Playing',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF00E5FF),
      ),
    );
    AudioHandlerSingleton.instance.handler = audioHandler;
  } catch (e, st) {
    debugPrint('[AudioService] init failed: $e\n$st');
    if (kDebugMode) _showCrashOverlay('AudioService Init Failed', '$e\n\n$st');
    // Continue without audio service — app can still launch
  }

  await runZonedGuarded(() async {
    await _initDatabase();
    final savedSettings = await AppSettings.load();

    runApp(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
              (ref) => SettingsNotifier(savedSettings)),
        ],
        child: const OtyaPlayerApp(),
      ),
    );

    unawaited(_initBackground(savedSettings));
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
    if (kDebugMode) _showCrashOverlay('Startup Crash', '$error\n\n$stack');
  });
}

// REMOVE before Play Store release — only shown in debug builds
void _showCrashOverlay(String title, String details) {
  // In release builds, errors are already logged via debugPrint.
  // Never show internal stack traces to end users in production.
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
                  'Screenshot this screen and share it here to debug the crash.',
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

Future<void> _initDatabase() async {
  try {
    await OtyaDatabase.instance.init();
  } catch (e, st) {
    debugPrint('[OtyaDB] Init error: $e\n$st');
    try {
      await OtyaDatabase.instance.deleteAndReinit();
    } catch (e2, st2) {
      debugPrint('[OtyaDB] deleteAndReinit also failed: $e2\n$st2');
      // App continues with DB unavailable — all DB calls are individually guarded
    }
  }
}

Future<void> _initBackground(AppSettings savedSettings) async {
  await Future.wait([
    _initNotifications(),
    _initWorkManager(),
    StorageFolderService.instance.ensureCreated(),
    // Bug 10 fix: initialize connectivity monitoring so isOffline is accurate
    // before any API call is made. ConnectivityService.instance.isOffline is
    // then checked by CloudflareService / ApiService before network requests.
    ConnectivityService.instance.init(),
    // Performance: initialize the Hive TTL cache for API responses.
    CacheService.instance.init(),
  ]);

  // Evict stale cache entries on startup (housekeeping).
  unawaited(CacheService.instance.evictExpired());

  // BUG 10: Replace UpdateService.registerDevice() (which sends incomplete
  // device info and causes double-registration) with DeviceService, which
  // includes model, Android version, locale, and only re-registers when the
  // build number changes.
  unawaited(DeviceService.instance.registerIfNeeded());
  unawaited(UpdateService.instance.checkAndNotify());

  // BUG 1: Register the PiP channel handler so MainActivity.kt's
  // onPause()/onResume() calls to invokeMethod('playerPause') and
  // invokeMethod('playerResume') are forwarded to the active media_kit Player.
  PipService.listenForNativePause(
    () => PlaybackCoordinator.instance.activePlayer?.pause(),
    () => PlaybackCoordinator.instance.activePlayer?.play(),
  );

  // BUG 2: Apply the persisted pauseDuringCalls setting on startup so Kotlin
  // registers (or skips) the TelephonyManager listener immediately, rather
  // than waiting for the user to open Settings and toggle the switch.
  unawaited(
    PhoneStateService.instance.setPauseDuringCalls(savedSettings.pauseDuringCalls),
  );

  // FcmService handles FCM token retrieval, persistence, and backend
  // registration — replaces the old manual _registerPushToken() call.
  unawaited(FcmService.instance.init());

  // CrashReporter installs Flutter/platform error handlers and uploads any
  // crashes that were stored while the device was offline.
  unawaited(CrashReporter.instance.init());
}

Future<void> _initNotifications() async {
  try {
    await NotificationService.instance.init();
    await UpdateNotificationService.instance.init();
    await MediaNotificationService.instance.init();
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('[Notifications] Init error: $e');
  }
}

// CloudflareService has no init — it is stateless HTTP. Accessed via singleton.
// ignore: unused_element
CloudflareService get _cf => CloudflareService.instance;

Future<void> _initWorkManager() async {
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    await Workmanager().registerPeriodicTask(
      'otya_update_check',
      'otya_update_check',
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    debugPrint('[WorkManager] Update check scheduled (24h).');
  } catch (e) {
    debugPrint('[WorkManager] Init error: $e');
  }
}
