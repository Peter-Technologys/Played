import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'core/database/played_database.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive database
  await PlayedDatabase.instance.init();

  // Initialize local notifications
  await NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: PlayedApp(),
    ),
  );
}
