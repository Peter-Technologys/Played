import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'playback_coordinator.dart';

/// Manages the persistent media playback notification with MediaStyle
/// (Android media controls on lock screen and notification shade).
///
/// Changes from original:
///   • Small icon changed from @mipmap/ic_launcher to @drawable/ic_notification
///     (white monochrome icon required by Android notification tray).
///   • _onAction now routes prev/play_pause/next to PlaybackCoordinator.
///   • updatePlayState() rebuilds only the play/pause action to avoid flicker.
///   • showWithBitmap() accepts raw album-art bytes (e.g. from the network)
///     via ByteArrayAndroidBitmap.
class MediaNotificationService {
  MediaNotificationService._();
  static final MediaNotificationService instance = MediaNotificationService._();

  static const _channelId   = 'otya_media_playback';
  static const _channelName = 'OTYA Player \u2014 Now Playing';
  static const _notifId     = 1000;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Cached state so updatePlayState() can rebuild without a full show() call.
  String?    _lastTitle;
  String?    _lastArtist;
  bool       _lastIsPlaying = false;
  String?    _lastAlbumArtPath;
  Uint8List? _lastAlbumArtBytes;

  Future<void> init() async {
    if (_initialized) return;
    // Use the monochrome notification icon — @mipmap/ic_launcher renders as a
    // coloured square in the status bar which violates Android design guidelines.
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onAction,
    );
    _initialized = true;
    debugPrint('[MediaNotificationService] Initialized.');
  }

  // ── Action handler ────────────────────────────────────────────────────────

  // Callback set by AudioPlayerNotifier so notification buttons can
  // trigger queue navigation without media_kit's internal playlist.
  void Function()? onSkipPrevious;
  void Function()? onSkipNext;

  void _onAction(NotificationResponse response) {
    final actionId = response.actionId;
    debugPrint('[MediaNotif] action: $actionId');

    final player = PlaybackCoordinator.instance.activePlayer;
    if (player == null) {
      debugPrint('[MediaNotif] No active player — ignoring action $actionId');
      return;
    }

    switch (actionId) {
      case 'prev':
        // Route through AudioPlayerNotifier queue logic, not media_kit playlist.
        if (onSkipPrevious != null) {
          onSkipPrevious!();
        } else if (player.state.position.inSeconds > 3) {
          player.seek(Duration.zero).ignore();
        }
      case 'play_pause':
        if (player.state.playing) {
          player.pause().ignore();
        } else {
          player.play().ignore();
        }
      case 'next':
        // Route through AudioPlayerNotifier queue logic, not media_kit playlist.
        onSkipNext?.call();
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Shows (or updates) the Now Playing notification with a file-path album art.
  Future<void> show({
    required String title,
    required String artist,
    required bool isPlaying,
    String? albumArtPath,
  }) async {
    if (!_initialized) await init();

    _lastTitle        = title;
    _lastArtist       = artist;
    _lastIsPlaying    = isPlaying;
    _lastAlbumArtPath = albumArtPath;
    _lastAlbumArtBytes = null;

    await _post(
      title:      title,
      artist:     artist,
      isPlaying:  isPlaying,
      largeIcon:  albumArtPath != null && File(albumArtPath).existsSync()
          ? FilePathAndroidBitmap(albumArtPath)
          : null,
    );
  }

  /// Shows (or updates) the Now Playing notification with in-memory album art
  /// (e.g. downloaded from the network).
  Future<void> showWithBitmap({
    required String title,
    required String artist,
    required bool isPlaying,
    required Uint8List albumArtBytes,
  }) async {
    if (!_initialized) await init();

    _lastTitle         = title;
    _lastArtist        = artist;
    _lastIsPlaying     = isPlaying;
    _lastAlbumArtPath  = null;
    _lastAlbumArtBytes = albumArtBytes;

    await _post(
      title:     title,
      artist:    artist,
      isPlaying: isPlaying,
      largeIcon: ByteArrayAndroidBitmap(albumArtBytes),
    );
  }

  /// Efficiently updates only the play/pause action without rebuilding the
  /// entire notification (avoids album-art flicker on rapid state changes).
  Future<void> updatePlayState(bool isPlaying) async {
    if (!_initialized) return;
    if (_lastTitle == null) return; // Nothing shown yet.

    _lastIsPlaying = isPlaying;

    AndroidBitmap<Object>? largeIcon;
    if (_lastAlbumArtBytes != null) {
      largeIcon = ByteArrayAndroidBitmap(_lastAlbumArtBytes!);
    } else if (_lastAlbumArtPath != null &&
        File(_lastAlbumArtPath!).existsSync()) {
      largeIcon = FilePathAndroidBitmap(_lastAlbumArtPath!);
    }

    await _post(
      title:     _lastTitle!,
      artist:    _lastArtist ?? '',
      isPlaying: isPlaying,
      largeIcon: largeIcon,
    );
  }

  Future<void> dismiss() async {
    if (!_initialized) return;
    await _plugin.cancel(_notifId);
    _lastTitle         = null;
    _lastArtist        = null;
    _lastAlbumArtPath  = null;
    _lastAlbumArtBytes = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _post({
    required String title,
    required String artist,
    required bool isPlaying,
    AndroidBitmap<Object>? largeIcon,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription:
          'Shows the currently playing track with media controls',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,        // Cannot be dismissed by swipe
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      // Use the monochrome white icon for the status bar / notification tray.
      icon: '@drawable/ic_notification',
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
      largeIcon: largeIcon,
    );

    await _plugin.show(
      _notifId,
      title,
      artist,
      NotificationDetails(android: androidDetails),
    );
  }
}
