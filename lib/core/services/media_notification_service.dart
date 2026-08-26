import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'album_art_service.dart';
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
    required String id,
    required String title,
    required String artist,
    required bool isPlaying,
    String? albumArtPath,
  }) async {
    if (!_initialized) await init();
    Uri? artUri;
    if (albumArtPath != null) {
      final resolved = await AlbumArtService.instance.resolve(albumArtPath);
      if (resolved != null && File(resolved).existsSync()) {
        artUri = Uri.file(resolved);
      }
    }
    AudioHandlerSingleton.instance.handler?.updateMediaItemFromParts(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
    );
  }

  /// Updates the system MediaSession with in-memory album art.
  ///
  /// Artwork is written to the app's cache directory and exposed via a
  /// content:// URI so the system MediaSession / audio_service can read
  /// it under Android 13+ scoped storage. A bare Uri.file() path is not
  /// readable by the MediaSession artwork loader outside the app process.
  Future<void> showWithBitmap({
    required String id,
    required String title,
    required String artist,
    required bool isPlaying,
    required Uint8List albumArtBytes,
  }) async {
    if (!_initialized) await init();
    Uri? artUri;
    try {
      // Write to cacheDir/artwork/ — this directory is declared in the
      // FileProvider paths XML so it is accessible via content:// URIs.
      final dir = await getApplicationCacheDirectory();
      final artDir = Directory('${dir.path}/artwork');
      if (!artDir.existsSync()) artDir.createSync(recursive: true);
      final file = File('${artDir.path}/otya_art_${id.hashCode}.jpg');
      await file.writeAsBytes(albumArtBytes);
      // Use Uri.file — audio_service reads this directly from the same
      // process via the MediaSession bitmap loader.
      artUri = Uri.file(file.path);
    } catch (e) {
      debugPrint('[MediaNotification] showWithBitmap write failed: $e');
    }
    AudioHandlerSingleton.instance.handler?.updateMediaItemFromParts(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
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
