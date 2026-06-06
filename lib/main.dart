import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/notification_service.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive local database
  await PlayedDatabase.instance.init();

  // Initialize local notifications (FFmpeg extraction progress)
  await NotificationService.instance.init();

  // Initialize Google Mobile Ads SDK
  // Replace test ad unit IDs with real ones before publishing
  await MobileAds.instance.initialize();

  // Pre-load persisted settings from SharedPreferences before runApp()
  final savedSettings = await AppSettings.load();

  runApp(
    ProviderScope(
      overrides: [
        // Seed settingsProvider with values loaded from SharedPreferences
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(savedSettings)),
      ],
      child: const PlayedApp(),
    ),
  );
}
