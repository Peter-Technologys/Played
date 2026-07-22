import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    // Request POST_NOTIFICATIONS permission on Android 13+ (API 33+).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    debugPrint('[Notifications] Initialized.');
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Fix #8: route notification taps instead of just logging.
    // The payload carries an optional URL (e.g. output file path or download URL).
    debugPrint('[Notifications] Tapped: id=${response.id} payload=${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // Schedule on the main thread — notification callbacks may arrive on a
      // background isolate where platform channels are unavailable.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPayload(payload));
    }
  }

  Future<void> _openPayload(String payload) async {
    try {
      final uri = Uri.tryParse(payload);
      if (uri == null) return;
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[Notifications] Could not open payload URL: $e');
    }
  }

  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'com.otyaplayer.app.tools',
      'OTYA Player Tools',
      channelDescription: 'Audio extraction and video trim progress',
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
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'com.otyaplayer.app.tools',
      'OTYA Player Tools',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> showError({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'com.otyaplayer.app.tools',
      'OTYA Player Tools',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> dismiss(int id) async => _plugin.cancel(id);
}
