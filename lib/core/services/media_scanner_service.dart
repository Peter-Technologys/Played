import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/media_item.dart';

/// Scans the device for all audio and video files.
///
/// Strategy:
///   1. Native MediaStore channel (PRIMARY) - works on ALL Android versions
///      with READ_MEDIA_AUDIO/VIDEO (API 33+) or READ_EXTERNAL_STORAGE
///      (API <= 32). Reads Android's media database directly.
///   2. Filesystem walk (FALLBACK) - used only if the channel returns
///      nothing (emulator, unusual ROM, or non-Android platform).
///
/// This is the same approach used by VLC, MX Player, and PlayIt.
class MediaScannerService {
  MediaScannerService._();
  static final MediaScannerService instance = MediaScannerService._();

  static const _channel = MethodChannel('com.petersmart.played/media_store');

  static const List<String> _videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'ts', 'webm', 'wmv', '3gp', 'm4v',
  ];

  static const List<String> _audioExtensions = [
    'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'wma', 'aiff',
  ];

  // Directories to skip during filesystem fallback scan only
  static const Set<String> _skipDirs = {
    'Android', '.thumbnails', '.cache', 'cache', 'obb',
    '.trash', 'lost+found',
    // 'data' intentionally removed - it was blocking legitimate folders
  };

  // PRIMARY: Native MediaStore query
  Future<List<MediaItem>> _queryMediaStore() async {
    try {
      final audioRaw =
          await _channel.invokeListMethod<Map>('queryAudio') ?? [];
      final videoRaw =
          await _channel.invokeListMethod<Map>('queryVideo') ?? [];

      final results = <MediaItem>[];
      const uuid = Uuid();

      for (final raw in [...audioRaw, ...videoRaw]) {
        final path = raw['path'] as String? ?? '';
        if (path.isEmpty) continue;

        final displayName =
            raw['displayName'] as String? ?? path.split('/').last;
        final title = displayName.replaceAll(RegExp(r'\.[^.]+$'), '');
        final durationMs = raw['durationMs'] as int? ?? 0;
        final size = raw['size'] as int? ?? 0;
        final dateAddedSec = raw['dateAdded'] as int? ?? 0;
        final isVideo = raw['isVideo'] as bool? ?? false;
        final albumId = raw['albumId'] as String?;

        results.add(MediaItem(
          id: uuid.v5(Namespace.url.value, path),
          title: title,
          fileName: displayName,
          filePath: path,
          isVideo: isVideo,
          duration:
              durationMs > 0 ? Duration(milliseconds: durationMs) : null,
          addedAt: dateAddedSec > 0
              ? DateTime.fromMillisecondsSinceEpoch(dateAddedSec * 1000)
              : DateTime.now(),
          fileSizeBytes: size,
          artist: raw['artist'] as String?,
          album: raw['album'] as String?,
          // Store albumId so UI can lazily fetch real album art
          albumArtPath: albumId != null ? 'albumid:$albumId' : null,
        ));
      }

      debugPrint('[Scanner] MediaStore: ${results.length} items found.');
      return results;
    } on MissingPluginException {
      debugPrint('[Scanner] MediaStore channel not available - using fallback.');
      return [];
    } catch (e) {
      debugPrint('[Scanner] MediaStore query failed: $e');
      return [];
    }
  }

  // FALLBACK: Filesystem walk
  Future<List<String>> _discoverRoots() async {
    final roots = <String>[];
    const internal = '/storage/emulated/0';
    if (await Directory(internal).exists()) roots.add(internal);
    try {
      final storageDir = Directory('/storage');
      await for (final entity in storageDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split('/').last;
          if (name != 'emulated' && name != 'self' && name.contains('-')) {
            roots.add(entity.path);
          }
        }
      }
    } catch (_) {}
    return roots;
  }

  Future<List<MediaItem>> _filesystemScan({
    void Function(int found)? onProgress,
  }) async {
    final results = <MediaItem>[];
    const uuid = Uuid();
    final roots = await _discoverRoots();
    for (final root in roots) {
      await _scanDir(Directory(root), results, uuid, onProgress);
    }
    debugPrint('[Scanner] Filesystem fallback: ${results.length} items found.');
    return results;
  }

  Future<void> _scanDir(
    Directory dir,
    List<MediaItem> results,
    Uuid uuid,
    void Function(int)? onProgress,
  ) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.path.split('/').last;
          if (_skipDirs.contains(name)) continue;
          await _scanDir(entity, results, uuid, onProgress);
        } else if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          final isVideo = _videoExtensions.contains(ext);
          final isAudio = _audioExtensions.contains(ext);
          if (!isVideo && !isAudio) continue;
          try {
            final stat = await entity.stat();
            if (stat.size < 10 * 1024) continue;
            final fileName = entity.path.split('/').last;
            final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
            results.add(MediaItem(
              id: uuid.v5(Namespace.url.value, entity.path),
              title: title,
              fileName: fileName,
              filePath: entity.path,
              isVideo: isVideo,
              addedAt: stat.modified,
              fileSizeBytes: stat.size,
            ));
            onProgress?.call(results.length);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[Scanner] Error scanning ${dir.path}: $e');
    }
  }

  // PUBLIC API

  /// Scans all media. Uses MediaStore first, filesystem walk as fallback.
  Future<List<MediaItem>> scanAll({
    void Function(int found)? onProgress,
  }) async {
    final storeResults = await _queryMediaStore();
    if (storeResults.isNotEmpty) return storeResults;
    return _filesystemScan(onProgress: onProgress);
  }

  /// Scans a single directory (used by folder browser).
  Future<List<MediaItem>> scanDirectory(String path) async {
    final results = <MediaItem>[];
    const uuid = Uuid();
    final dir = Directory(path);
    if (!await dir.exists()) return results;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final ext = entity.path.split('.').last.toLowerCase();
        final isVideo = _videoExtensions.contains(ext);
        final isAudio = _audioExtensions.contains(ext);
        if (!isVideo && !isAudio) continue;
        try {
          final stat = await entity.stat();
          if (stat.size < 10 * 1024) continue;
          final fileName = entity.path.split('/').last;
          results.add(MediaItem(
            id: uuid.v5(Namespace.url.value, entity.path),
            title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
            fileName: fileName,
            filePath: entity.path,
            isVideo: isVideo,
            addedAt: stat.modified,
            fileSizeBytes: stat.size,
          ));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Scanner] scanDirectory error: $e');
    }
    return results;
  }
}
