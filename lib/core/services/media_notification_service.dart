import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'album_art_service.dart';
import 'audio_handler.dart';
import 'shared_notification_plugin.dart';

/// Owns system Now Playing metadata for notification shade, lock screen,
/// Bluetooth/headset controls and Android media surfaces.
class MediaNotificationService {
  MediaNotificationService._();
  static final MediaNotificationService instance = MediaNotificationService._();

  bool _initialized = false;
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
    final artUri = await _stableArtUri(albumArtPath, id);
    AudioHandlerSingleton.instance.handler?.updateMediaItemFromParts(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
    );
  }

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
      final dir = await _artworkDir();
      final file = File('${dir.path}/now_playing_${id.hashCode}.jpg');
      await file.writeAsBytes(albumArtBytes, flush: true);
      artUri = Uri.file(file.path);
      _lastArtworkKey = '$id|bitmap';
      _lastArtworkUri = artUri;
    } catch (e) {
      debugPrint('[MediaNotification] bitmap cache failed: $e');
    }
    AudioHandlerSingleton.instance.handler?.updateMediaItemFromParts(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
    );
  }

  Future<void> updatePlayState(bool isPlaying) async {}

  Future<void> dismiss() async {
    _lastArtworkKey = null;
    _lastArtworkUri = null;
    AudioHandlerSingleton.instance.handler?.mediaItem.add(null);
  }
}
