// One FlutterLocalNotificationsPlugin shared by OTYA's local notification
// owners so Android channel registration and tap handling stay centralized.
//
// Notification routing:
//   2000-2003 -> PushNotificationService (updates, downloads, announcements)
//   everything else -> NotificationService (tool/local notifications)
//
// Media playback notifications are owned by audio_service/MediaSession and do
// not go through this plugin.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';
import 'push_notification_service.dart';

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
  if (id >= 2000 && id <= 2003) {
    PushNotificationService.instance.handleTap(response);
    return;
  }
  NotificationService.instance.handleTap(response);
}
