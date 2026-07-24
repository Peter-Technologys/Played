import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages the persistent media playback notification with MediaStyle
/// (Android media controls on lock screen and notification shade).
class MediaNotificationService {
  MediaNotificationService._();
  static final MediaNotificationService instance = MediaNotificationService._();

  static const _channelId   = 'com.otyaplayer.app.media_playback';
  static const _channelName = 'OTYA Player — Now Playing';
  static const _notifId     = 1000;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onAction,
    );
    _initialized = true;
    debugPrint('[MediaNotificationService] Initialized.');
  }

  void _onAction(NotificationResponse response) {
    // Actions are handled by the app via the coordinator
    debugPrint('[MediaNotif] action: ${response.actionId}');
  }

  Future<void> show({
    required String title,
    required String artist,
    required bool isPlaying,
    String? albumArtPath,
  }) async {
    if (!_initialized) await init();

    // Build the MediaStyle notification with play/pause + prev/next actions
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows the currently playing track with media controls',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,           // Cannot be dismissed by swipe
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      styleInformation: const MediaStyleInformation(),
      actions: [
        const AndroidNotificationAction(
          'prev',
          'Previous',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_skip_previous'),
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'play_pause',
          isPlaying ? 'Pause' : 'Play',
          icon: DrawableResourceAndroidBitmap(
            isPlaying ? '@drawable/ic_pause' : '@drawable/ic_play_arrow',
          ),
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          'next',
          'Next',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_skip_next'),
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
      largeIcon: albumArtPath != null && File(albumArtPath).existsSync()
          ? FilePathAndroidBitmap(albumArtPath)
          : null,
    );

    await _plugin.show(
      _notifId,
      title,
      artist,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> dismiss() async {
    if (!_initialized) return;
    await _plugin.cancel(_notifId);
  }
}
