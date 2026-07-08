import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_service.dart';

/// Builds and shows high-priority update notifications.
///
/// Channel: "Updates" (IMPORTANCE_HIGH)
/// Notification ID: 9001 (reserved — will not conflict with tools channel)
///
/// Action buttons:
///   "Download Now" → opens Worker /download URL in browser
///   "Later"        → dismisses (WorkManager will re-check in 24h)
class UpdateNotificationService {
  UpdateNotificationService._();
  static final UpdateNotificationService instance = UpdateNotificationService._();

  static const int    _notificationId  = 9001;
  static const String _channelId       = 'com.otyaplayer.app.updates';
  static const String _channelName     = 'Updates';
  static const String _channelDesc     = 'OTYA Player app update notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _showing     = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
    debugPrint('[UpdateNotification] Initialized.');
  }

  /// Shows a high-priority update notification with Download Now / Later actions.
  /// Guards against concurrent calls so only one notification is shown at a time.
  Future<void> showUpdateNotification(UpdateInfo info) async {
    if (_showing) return;
    _showing = true;
    if (!_initialized) await init();

    final changelog = info.changelog.length > 200
        ? '${info.changelog.substring(0, 197)}...'
        : info.changelog;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF8A2BE2),
      styleInformation: BigTextStyleInformation(
        changelog,
        contentTitle: 'OTYA Player ${info.version} is available',
        summaryText: 'Tap to download',
      ),
      actions: [
        const AndroidNotificationAction(
          'download',
          'Download Now',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'later',
          'Later',
          cancelNotification: true,
        ),
      ],
      ongoing: false,
      autoCancel: true,
      ticker: 'OTYA Player update available',
    );

    await _plugin.show(
      _notificationId,
      'OTYA Player Update Available',
      'Version ${info.version} — $changelog',
      NotificationDetails(android: androidDetails),
      payload: info.downloadUrl,
    );

    _showing = false;
    debugPrint('[UpdateNotification] Shown for v${info.version}.');
  }

  Future<void> dismiss() async => _plugin.cancel(_notificationId);

  void _onNotificationTap(NotificationResponse response) {
    final action = response.actionId;
    final url    = response.payload ?? '';

    if (action == 'download' || (action == null && url.isNotEmpty)) {
      // Notification callbacks may arrive on a background isolate.
      // Schedule on the main thread to safely call platform channels.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openUrl(url));
    }
    // 'later' just dismisses — WorkManager will re-check in 24h
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[UpdateNotification] Could not open URL: $e');
    }
  }
}
