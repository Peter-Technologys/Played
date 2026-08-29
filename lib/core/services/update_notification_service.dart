import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import 'shared_notification_plugin.dart';
import 'update_service.dart';

/// Builds and shows high-priority OTYA update notifications.
class UpdateNotificationService {
  UpdateNotificationService._();
  static final UpdateNotificationService instance = UpdateNotificationService._();

  static const int _notificationId = 9001;
  static const String _channelId = 'com.otyaplayer.app.updates';
  static const String _channelName = 'OTYA Updates';
  static const String _channelDesc = 'OTYA app update notifications';

  bool _initialized = false;
  bool _showing = false;

  Future<void> init() async {
    if (_initialized) return;
    await initSharedNotificationsPlugin();
    _initialized = true;
    debugPrint('[UpdateNotification] Initialized.');
  }

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
      icon: '@drawable/ic_notification',
      color: AppColors.accentViolet,
      styleInformation: BigTextStyleInformation(
        changelog,
        contentTitle: 'OTYA ${info.version} is available',
        summaryText: 'Tap to download',
      ),
      actions: [
        const AndroidNotificationAction(
          'download',
          'Download now',
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
      ticker: 'OTYA update available',
    );

    await sharedNotificationsPlugin.show(
      _notificationId,
      'OTYA update available',
      'Version ${info.version} — $changelog',
      NotificationDetails(android: androidDetails),
      payload: info.downloadUrl,
    );

    _showing = false;
    debugPrint('[UpdateNotification] Shown for v${info.version}.');
  }

  Future<void> dismiss() async =>
      sharedNotificationsPlugin.cancel(_notificationId);

  /// Public entry-point called by [sharedNotificationRouter].
  void handleTap(NotificationResponse response) => _onNotificationTap(response);

  void _onNotificationTap(NotificationResponse response) {
    final action = response.actionId;
    final url = response.payload ?? '';

    if (action == 'download' || (action == null && url.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openUrl(url));
    }
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
