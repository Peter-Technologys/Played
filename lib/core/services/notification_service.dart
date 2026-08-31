import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shared_notification_plugin.dart';

/// Manages OTYA local notifications.
///
/// Notification permission is deliberately NOT requested from [init]. On
/// Android 13+ the user first sees OTYA's onboarding explanation, then the
/// platform prompt is requested contextually.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    await initSharedNotificationsPlugin();
    debugPrint('[Notifications] Initialized.');
  }

  /// Requests Android 13+ notification permission after OTYA has explained
  /// that it is used for Now Playing controls, lock-screen playback and tool
  /// progress. Older Android versions return true without a runtime prompt.
  Future<bool> requestPermission() async {
    final android = sharedNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Public entry-point called by [sharedNotificationRouter].
  void handleTap(NotificationResponse response) =>
      _onNotificationResponse(response);

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
      '[Notifications] Tapped: id=${response.id} payload=${response.payload}',
    );
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPayload(payload));
    }
  }

  bool _isSafePayload(Uri uri) {
    if (uri.scheme == 'file') return uri.path.isNotEmpty;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
    return true;
  }

  Future<void> _openPayload(String payload) async {
    try {
      final uri = Uri.tryParse(payload);
      if (uri == null || !_isSafePayload(uri)) {
        debugPrint('[Notifications] Ignored unsafe payload.');
        return;
      }
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
    final safeProgress = progress.clamp(0, 100).toInt();
    final androidDetails = AndroidNotificationDetails(
      'com.otyaplayer.app.tools.progress',
      'OTYA Player Tools — Progress',
      channelDescription: 'Audio extraction and video trim progress (silent)',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: safeProgress,
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
      'OTYA Player Tools — Complete',
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
      'OTYA Player Tools — Error',
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
