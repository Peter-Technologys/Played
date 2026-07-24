import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:workmanager/workmanager.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/cloudflare_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/media_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/storage_folder_service.dart';
import 'core/services/otya_service.dart';
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
    _initNotifications(),
    _initWorkManager(),
    StorageFolderService.instance.ensureCreated(),
  ]);

  unawaited(UpdateService.instance.registerDevice());
  unawaited(UpdateService.instance.checkAndNotify());
  // BUG 5: Wire up OtyaService.registerDevicePushToken using the FCM token
  // and device ID already stored in SharedPreferences by UpdateService.
  // This avoids adding firebase_messaging as a new dependency — the token
  // is written to 'fcm_token' by the native layer (if present).
  unawaited(_registerPushToken());
}

Future<void> _registerPushToken() async {
  try {
    final prefs    = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('update_device_id');
    final fcmToken = prefs.getString('fcm_token');
    if (deviceId != null && fcmToken != null && fcmToken.isNotEmpty) {
      await OtyaService.instance.registerDevicePushToken(
        deviceId: deviceId,
        fcmToken: fcmToken,
      );
    }
  } catch (e) {
    debugPrint('[main] _registerPushToken failed (non-fatal): $e');
  }
}

Future<void> _initNotifications() async {
  try {
    await NotificationService.instance.init();
    await UpdateNotificationService.instance.init();
    await MediaNotificationService.instance.init();
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
