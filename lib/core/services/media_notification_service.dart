import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'album_art_service.dart';
import 'audio_handler.dart';
import 'notification_service.dart';
import 'shared_notification_plugin.dart';

/// Owns system Now Playing metadata for notification shade, lock screen,
/// Bluetooth/headset controls and Android media surfaces.
class MediaNotificationService {
  MediaNotificationService._();
  static final MediaNotificationService instance = MediaNotificationService._();

  bool _initialized = false;
  bool _permissionChecked = false;
  String? _lastArtworkKey;
  Uri? _lastArtworkUri;

  void Function()? onSkipPrevious;
  void Function()? onSkipNext;

  Future<void> init() async {
    if (_initialized) return;
    await initSharedNotificationsPlugin();
    _initialized = true;
    debugPrint('[MediaNotificationService] Initialized.');
  }

  Future<void> _ensureNotificationPermission() async {
    if (_permissionChecked) return;
    _permissionChecked = true;
    try {
      final granted = await NotificationService.instance.requestPermission();
      debugPrint('[MediaNotificationService] Notification permission: $granted');
    } catch (e) {
      debugPrint('[MediaNotificationService] Permission request skipped: $e');
    }
  }

  Future<Directory> _artworkDir() async {
    final cache = await getApplicationCacheDirectory();
    final dir = Directory('${cache.path}/now_playing_art');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<Uri?> _stableArtUri(String? albumArtPath, String id) async {
    if (albumArtPath == null || albumArtPath.isEmpty) return null;
    final resolved = await AlbumArtService.instance.resolve(albumArtPath);
    if (resolved == null || resolved.isEmpty) return null;

    final source = File(resolved);
    if (!await source.exists()) return null;

    final key = '$id|$resolved';
    if (_lastArtworkKey == key && _lastArtworkUri != null) {
      return _lastArtworkUri;
    }

    try {
      final dir = await _artworkDir();
      final ext = resolved.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final target = File('${dir.path}/now_playing_${id.hashCode}.$ext');
      await source.copy(target.path);
      final uri = Uri.file(target.path);
      _lastArtworkKey = key;
      _lastArtworkUri = uri;
      return uri;
    } catch (e) {
      debugPrint('[MediaNotification] artwork cache failed: $e');
      return Uri.file(source.path);
    }
  }

  Future<void> show({
    required String id,
    required String title,
    required String artist,
    required bool isPlaying,
    String? albumArtPath,
  }) async {
    if (!_initialized) await init();
    await _ensureNotificationPermission();
    final artUri = await _stableArtUri(albumArtPath, id);
    final handler = AudioHandlerSingleton.instance.handler;
    handler?.updateMediaItemFromParts(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
    );
    await updatePlayState(isPlaying);
  }

  Future<void> showWithBitmap({
    required String id,
    required String title,
    required String artist,
    required bool isPlaying,
    required Uint8List albumArtBytes,
  }) async {
    if (!_initialized) await init();
    await _ensureNotificationPermission();
    Uri? artUri;
    try {
      final dir = await _artworkDir();
      final file = File('${dir.path}/now_playing_${id.hashCode}.jpg');
      await file.writeAsBytes(albumArtBytes, flush: true);
      artUri = Uri.file(file.path);
      _lastArtworkKey = '$id|bitmap';
      _lastArtworkUri = artUri;
    } catch (e) {
      debugPrint('[MediaNotification] bitmap cache failed: $e');
    }
    final handler = AudioHandlerSingleton.instance.handler;
    handler?.updateMediaItemFromParts(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
    );
    await updatePlayState(isPlaying);
  }

  Future<void> updatePlayState(bool isPlaying) async {
    final handler = AudioHandlerSingleton.instance.handler;
    if (handler == null) return;
    final current = handler.playbackState.value;
    handler.playbackState.add(current.copyWith(
      playing: isPlaying,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 2, 4],
    ));
  }

  Future<void> dismiss() async {
    _lastArtworkKey = null;
    _lastArtworkUri = null;
    final handler = AudioHandlerSingleton.instance.handler;
    handler?.mediaItem.add(null);
    if (handler != null) {
      handler.playbackState.add(handler.playbackState.value.copyWith(
        playing: false,
        controls: const [],
      ));
    }
  }
}
