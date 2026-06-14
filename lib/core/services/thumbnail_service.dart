import 'package:flutter/services.dart';

/// Dart wrapper for video thumbnail and album art native calls.
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  static const _ch = MethodChannel('com.petersmart.played/media_store');

  /// Returns a cached local JPEG path for a video thumbnail, or null.
  Future<String?> videoThumbnail(String videoPath, String videoId) async {
    try {
      return await _ch.invokeMethod<String>(
          'getVideoThumbnail', {'path': videoPath, 'id': videoId});
    } catch (_) {
      return null;
    }
  }

  /// Returns a cached local JPEG path for album art, or null.
  Future<String?> albumArt(String albumId) async {
    try {
      return await _ch.invokeMethod<String>(
          'getAlbumArt', {'albumId': albumId});
    } catch (_) {
      return null;
    }
  }
}
