import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Manages local notifications for FFmpeg extraction progress.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings =
        InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    debugPrint('[Notifications] Initialized.');
  }

  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'played_extraction',
      'Audio Extraction',
      channelDescription: 'Shows MP4 to MP3 extraction progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
      ongoing: true,
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showComplete({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'played_extraction',
      'Audio Extraction',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showError({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'played_extraction',
      'Audio Extraction',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> dismiss(int id) async => _plugin.cancel(id);
}
