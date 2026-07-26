import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'audio_handler.dart';
import 'shared_notification_plugin.dart';

/// Manages the media playback notification / MediaSession metadata.
///
/// Previously this posted a MediaStyle notification via
/// flutter_local_notifications (ID 1000). It now delegates to
/// [OtyaAudioHandler.updateMediaItem] instead, which updates the system
/// MediaSession. audio_service renders the notification natively via
/// MediaSession — no flutter_local_notifications involvement for media.
///
/// The shared plugin is still initialised here because other services
/// (UpdateNotificationService, PushNotificationService, NotificationService)
/// depend on it.
class MediaNotificationService {
  MediaNotificationService._();
  static final MediaNotificationService instance = MediaNotificationService._();

  bool _initialized = false;

  // Callbacks wired by AudioPlayerNotifier so notification skip buttons
  // can trigger queue navigation.
  void Function()? onSkipPrevious;
  void Function()? onSkipNext;

  Future<void> init() async {
    if (_initialized) return;
    await initSharedNotificationsPlugin();
    _initialized = true;
    debugPrint('[MediaNotificationService] Initialized.');
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Updates the system MediaSession with track metadata.
  /// The audio_service foreground service renders the notification.
  Future<void> show({
    required String title,
    required String artist,
    required bool isPlaying,
    String? albumArtPath,
  }) async {
    if (!_initialized) await init();
    Uri? artUri;
    if (albumArtPath != null && File(albumArtPath).existsSync()) {
      artUri = Uri.file(albumArtPath);
    }
    AudioHandlerSingleton.instance.handler?.updateMediaItemFromParts(
      title: title,
      artist: artist,
      artUri: artUri,
    );
  }

  /// Updates the system MediaSession with in-memory album art.
  Future<void> showWithBitmap({
    required String title,
    required String artist,
    required bool isPlaying,
    required Uint8List albumArtBytes,
  }) async {
    if (!_initialized) await init();
    // audio_service does not support raw bytes for artUri directly;
    // pass without art — the title/artist still show on the lock screen.
    AudioHandlerSingleton.instance.handler?.updateMediaItemFromParts(
      title: title,
      artist: artist,
    );
  }

  /// No-op: playbackState is updated automatically by OtyaAudioHandler
  /// stream subscriptions whenever the Player emits a playing event.
  Future<void> updatePlayState(bool isPlaying) async {}

  /// Clears the MediaSession metadata.
  Future<void> dismiss() async {
    AudioHandlerSingleton.instance.handler?.mediaItem.add(null);
  }
}
