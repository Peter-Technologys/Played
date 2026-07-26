import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resolves `albumid:NNNN` album-art paths to real file-system paths by
/// calling the `getAlbumArt` method on the `com.otyaplayer.app/media_store`
/// MethodChannel.
///
/// The MediaScanner returns `albumArtPath: 'albumid:<id>'` for audio items
/// because the album art is stored in the Android MediaStore, not as a
/// standalone file. Kotlin's `getAlbumArt` handler queries
/// `MediaStore.Audio.Albums` and returns the `ALBUM_ART` column value (a
/// real file path) for the given album ID.
///
/// Results are cached in memory so repeated lookups for the same album are
/// free after the first call.
class AlbumArtService {
  AlbumArtService._();
  static final AlbumArtService instance = AlbumArtService._();

  static const _channel = MethodChannel('com.otyaplayer.app/media_store');

  /// Maximum number of entries kept in the in-memory cache.
  /// When exceeded the entire cache is cleared to bound memory usage.
  static const int _maxCacheSize = 500;

  /// Simple in-memory cache: albumId → resolved file path (or null if failed).
  final Map<String, String?> _cache = {};

  /// Resolves an `albumid:NNNN` path to a real file path.
  ///
  /// - If [albumArtPath] is null, returns null.
  /// - If [albumArtPath] does not start with `albumid:`, it is already a real
  ///   path and is returned as-is.
  /// - If the native call fails or returns null, returns null and caches the
  ///   failure so we don't hammer the channel on every rebuild.
  Future<String?> resolve(String? albumArtPath) async {
    if (albumArtPath == null) return null;
    if (!albumArtPath.startsWith('albumid:')) return albumArtPath;

    final albumId = albumArtPath.replaceFirst('albumid:', '');

    // Return cached result (including cached null for known failures).
    if (_cache.containsKey(albumId)) return _cache[albumId];

    // Evict the entire cache when it exceeds the size cap to prevent
    // unbounded memory growth on devices with thousands of albums.
    if (_cache.length >= _maxCacheSize) _cache.clear();

    try {
      final path = await _channel.invokeMethod<String>(
        'getAlbumArt',
        {'albumId': albumId},
      );
      _cache[albumId] = path;
      return path;
    } catch (e) {
      debugPrint('[AlbumArt] resolve failed for albumId=$albumId: $e');
      _cache[albumId] = null;
      return null;
    }
  }
}
