import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// WorkManager callback dispatcher — must be a top-level function.
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

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.summary}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    return true;
  };

  // ── Fast path: only the minimum before runApp ─────────────────────
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

  // ── Background init after first frame ─────────────────────────────
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
  await Future.wait([
    _initAudioService(),
    _initNotifications(),
    _initAppwrite(),
    _initWorkManager(),
    StorageFolderService.instance.ensureCreated(),
  ]);

  // Register device + run immediate update check after everything is ready
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
    // Register periodic update check — KEEP policy, won't duplicate
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
