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
import 'core/services/cloudflare_service.dart';
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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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
    if (kDebugMode) {
      _showCrashOverlay('Flutter Error', '${details.summary}\n\n${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    unawaited(CrashReporter.instance.report(error, stack));
    if (kDebugMode) {
      _showCrashOverlay('Platform Error', '$error\n\n$stack');
    }
    return true;
  };

  try {
    final audioHandler = await AudioService.init(
      builder: () => OtyaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.otyaplayer.app.audio',
        androidNotificationChannelName: 'OTYA Player — Now Playing',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'drawable/ic_notification',
        notificationColor: Color(0xFF00E5FF),
        androidShowNotificationBadge: false,
        preloadArtwork: true,
      ),
    );
    AudioHandlerSingleton.instance.handler = audioHandler;
  } catch (e, st) {
    debugPrint('[AudioService] init failed: $e\n$st');
    unawaited(CrashReporter.instance.report(e, st));
  }

  await runZonedGuarded(() async {
    await _initDatabase();
    final savedSettings = await AppSettings.load();

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

    unawaited(
      _initBackground(savedSettings).catchError((Object e, StackTrace st) {
        debugPrint('[Background init] Error: $e\n$st');
        unawaited(CrashReporter.instance.report(e, st));
      }),
    );
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
    unawaited(CrashReporter.instance.report(error, stack));
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

Future<void> _initDatabase() async {
  try {
    await OtyaDatabase.instance.init();
  } catch (e, st) {
    debugPrint('[OtyaDB] Init error: $e\n$st');
    try {
      await OtyaDatabase.instance.deleteAndReinit();
    } catch (e2, st2) {
      debugPrint('[OtyaDB] deleteAndReinit also failed: $e2\n$st2');
    }
  }
}

Future<void> _initBackground(AppSettings savedSettings) async {
  await Future.wait([
    _initNotifications(),
    StorageFolderService.instance.ensureCreated(),
    ConnectivityService.instance.init(),
    CacheService.instance.init(),
  ]);

  unawaited(CacheService.instance.evictExpired());
  unawaited(DeviceService.instance.registerIfNeeded());
  unawaited(UpdateService.instance.checkAndNotify());

  PipService.listenForNativePause(
    () => PlaybackCoordinator.instance.activePlayer?.pause(),
    () => PlaybackCoordinator.instance.activePlayer?.play(),
  );

  unawaited(
    PhoneStateService.instance.setPauseDuringCalls(
      savedSettings.pauseDuringCalls,
    ),
  );
  unawaited(FcmService.instance.init());
  unawaited(CrashReporter.instance.init());
}

Future<void> _initNotifications() async {
  try {
    await NotificationService.instance.init();
    await UpdateNotificationService.instance.init();
    await MediaNotificationService.instance.init();
    await PushNotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[Notifications] Init error: $e\n$st');
    unawaited(CrashReporter.instance.report(e, st));
  }
}

// CloudflareService has no init — it is stateless HTTP. Accessed via singleton.
// ignore: unused_element
CloudflareService get _cf => CloudflareService.instance;
