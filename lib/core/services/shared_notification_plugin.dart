// A single FlutterLocalNotificationsPlugin shared across all notification
// services to avoid duplicate Android channel registrations and conflicting
// onDidReceiveNotificationResponse callbacks.
//
// Notification ID routing:
//   9001      -> UpdateNotificationService (update download)
//   2000-2003 -> PushNotificationService   (FCM push)
//   else      -> NotificationService       (FFmpeg tools)
//
// Note: Media playback notifications (previously ID 1000) are now handled
// natively by audio_service via the system MediaSession. They no longer
// go through this plugin.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';
import 'push_notification_service.dart';
import 'update_notification_service.dart';

final sharedNotificationsPlugin = FlutterLocalNotificationsPlugin();
bool _sharedPluginInitialized = false;

Future<void> initSharedNotificationsPlugin() async {
  if (_sharedPluginInitialized) return;
  const androidSettings =
      AndroidInitializationSettings('@drawable/ic_notification');
  await sharedNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: sharedNotificationRouter,
  );
  _sharedPluginInitialized = true;
}

void sharedNotificationRouter(NotificationResponse response) {
  final id = response.id ?? -1;
  if (id == 9001) {
    UpdateNotificationService.instance.handleTap(response);
  } else if (id >= 2000 && id <= 2003) {
    PushNotificationService.instance.handleTap(response);
  } else if (id == 3000) {
    // ProChurnService notification - open payload URL
    NotificationService.instance.handleTap(response);
  } else {
    NotificationService.instance.handleTap(response);
  }
}
