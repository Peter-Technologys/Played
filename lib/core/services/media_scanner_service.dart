import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/media_item.dart';

/// Scans device storage for all audio and video files.
/// Discovers storage roots dynamically (internal + SD cards).
class MediaScannerService {
  MediaScannerService._();
  static final MediaScannerService instance = MediaScannerService._();

  static const List<String> _videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'ts', 'webm', 'wmv', '3gp', 'm4v',
  ];

  static const List<String> _audioExtensions = [
    'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'wma', 'aiff',
  ];

  // Directories to skip — system/cache folders that waste scan time
  static const Set<String> _skipDirs = {
    'Android', '.thumbnails', '.cache', 'cache', 'obb',
    '.trash', 'lost+found', 'data',
  };

  /// Discovers all available storage roots (internal + SD cards).
  Future<List<String>> _discoverRoots() async {
    final roots = <String>[];
    // Internal storage
    const internal = '/storage/emulated/0';
    if (await Directory(internal).exists()) roots.add(internal);

    // SD cards — /storage/ contains XXXX-XXXX style entries
    try {
      final storageDir = Directory('/storage');
      await for (final entity in storageDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split('/').last;
          // Skip emulated and self — only real SD card mounts
          if (name != 'emulated' && name != 'self' && name.contains('-')) {
            roots.add(entity.path);
          }
        }
      }
    } catch (_) {}

    return roots;
  }

  /// Full device scan. Returns all discovered [MediaItem]s.
  /// Runs directory traversal with skip-list to avoid system folders.
  Future<List<MediaItem>> scanAll({
    void Function(int found)? onProgress,
  }) async {
    final results = <MediaItem>[];
    const uuid = Uuid();
    final roots = await _discoverRoots();

    for (final root in roots) {
      await _scanDir(Directory(root), results, uuid, onProgress);
    }

    debugPrint('[Scanner] Found ${results.length} media files.');
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
            // Skip empty/tiny files (< 10 KB) — likely corrupt or temp
            if (stat.size < 10 * 1024) continue;

            final fileName = entity.path.split('/').last;
            final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

            results.add(MediaItem(
              id: uuid.v5(Uuid.NAMESPACE_URL, entity.path),
              title: title,
              fileName: fileName,
              filePath: entity.path,
              isVideo: isVideo,
              addedAt: stat.modified,
              fileSizeBytes: stat.size,
            ));
            onProgress?.call(results.length);
          } catch (_) {
            // Skip unreadable files
          }
        }
      }
    } catch (e) {
      debugPrint('[Scanner] Error scanning ${dir.path}: $e');
    }
  }

  /// Scans a single directory (non-recursive).
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
            id: uuid.v5(Uuid.NAMESPACE_URL, entity.path),
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
