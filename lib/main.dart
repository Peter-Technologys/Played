import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:workmanager/workmanager.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/audio_handler.dart';
import 'core/services/appwrite_service.dart';
import 'core/services/notification_service.dart';
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
  // Fix #7: media_kit requires this before runApp() — without it, video
  // playback silently fails on some devices (native libs not loaded).
  MediaKit.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.summary}\n${details.stack}');
    _showCrashOverlay('Flutter Error', '${details.summary}\n\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    _showCrashOverlay('Platform Error', '$error\n\n$stack');
    return true;
  };

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

    unawaited(_initBackground());
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
    _showCrashOverlay('Startup Crash', '$error\n\n$stack');
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
    await PlayedDatabase.instance.init();
  } catch (e, st) {
    debugPrint('[PlayedDB] Init error: $e\n$st');
    try {
      await PlayedDatabase.instance.deleteAndReinit();
    } catch (_) {}
  }
}

Future<void> _initBackground() async {
  await Future.wait([
    _initAudioService(),
    _initNotifications(),
    _initAppwrite(),
    _initWorkManager(),
    StorageFolderService.instance.ensureCreated(),
  ]);

  unawaited(UpdateService.instance.registerDevice());
  unawaited(UpdateService.instance.checkAndNotify());
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
    await UpdateNotificationService.instance.init();
  } catch (e) {
    debugPrint('[Notifications] Init error: $e');
  }
}

Future<void> _initAppwrite() async {
  try {
    AppwriteService.instance.init();
  } catch (e) {
    debugPrint('[Appwrite] Init error: $e');
  }
}

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
