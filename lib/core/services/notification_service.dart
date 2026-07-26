import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shared_notification_plugin.dart';

/// Manages local notifications for FFmpeg extraction progress.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    await initSharedNotificationsPlugin();
    // Request POST_NOTIFICATIONS permission on Android 13+ (API 33+).
    await sharedNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    debugPrint('[Notifications] Initialized.');
  }

  /// Public entry-point called by [sharedNotificationRouter].
  void handleTap(NotificationResponse response) => _onNotificationResponse(response);

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('[Notifications] Tapped: id=${response.id} payload=${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
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
      'com.otyaplayer.app.tools.progress',
      'OTYA Player Tools \u2014 Progress',
      channelDescription: 'Audio extraction and video trim progress (silent)',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
      ongoing: true,
    );
    await sharedNotificationsPlugin.show(
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
      'com.otyaplayer.app.tools.complete',
      'OTYA Player Tools \u2014 Complete',
      channelDescription: 'Audio extraction and video trim completion alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    await sharedNotificationsPlugin.show(
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
      'com.otyaplayer.app.tools.error',
      'OTYA Player Tools \u2014 Error',
      channelDescription: 'Audio extraction and video trim error alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    await sharedNotificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> dismiss(int id) async => sharedNotificationsPlugin.cancel(id);
}
