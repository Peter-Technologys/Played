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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // MediaKit must be initialized before any Player is created.
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
    CrashReporter.instance.report(details.exception, details.stack ?? StackTrace.empty);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    CrashReporter.instance.report(error, stack);
    return true;
  };

  await runZonedGuarded(() async {
    // Keep only lightweight, recoverable storage initialization on the
    // critical startup path. AudioService and network/background work are
    // intentionally initialized after the first Flutter frame so a native
    // service failure cannot prevent the app UI from opening.
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
        CrashReporter.instance.report(e, st);
      }),
    );
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
    CrashReporter.instance.report(error, stack);
  });
}

Future<void> _initAudioService() async {
  // AudioService is a native Android foreground service. It must not sit on
  // the critical startup path because OEM-specific service failures can crash
  // an otherwise healthy Flutter application before its first frame.
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
    // Playback remains available through media_kit even if the optional
    // background media service cannot be started on a particular device.
    debugPrint('[AudioService] deferred init failed: $e\n$st');
    CrashReporter.instance.report(e, st);
  }
}

Future<void> _initDatabase() async {
  try {
    await OtyaDatabase.instance.init();
  } catch (e, st) {
    // Do not wipe the user's entire database automatically. A destructive
    // reset during startup can turn a recoverable storage problem into data
    // loss and does not fix every possible Hive initialization failure.
    debugPrint('[OtyaDB] Init error: $e\n$st');
    CrashReporter.instance.report(e, st);
  }
}

Future<void> _initBackground(AppSettings savedSettings) async {
  // Start the native audio service independently from network/background
  // initialization. This keeps failures isolated.
  unawaited(_initAudioService());

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
  } catch (e) {
    debugPrint('[Notifications] Init error: $e');
  }
}
