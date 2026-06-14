import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — wrapped in try/catch so the app launches
  // fully offline (e.g. installed via Xender with no internet).
  // Auth and Firestore sync silently in the background once online.
  _initFirebaseInBackground();

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

/// Initialises Firebase and anonymous auth in the background.
/// Never blocks the app launch — all Firebase features degrade gracefully
/// when offline. Local Hive + SharedPreferences always work regardless.
void _initFirebaseInBackground() {
  Future(() async {
    try {
      await Firebase.initializeApp();
      await AuthService.instance.signInAnonymouslyIfNeeded();
    } catch (e) {
      // Offline or Firebase unavailable — app continues with local storage.
      // Auth will retry automatically next time the user opens the app
      // with an internet connection.
      debugPrint('[Firebase] Background init failed (offline?): $e');
    }
  });
}
