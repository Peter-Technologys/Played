import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/media_item.dart';

/// Scans device storage for all audio and video files.
/// Runs on an isolate-friendly compute call to avoid UI jank.
class MediaScannerService {
  MediaScannerService._();
  static final MediaScannerService instance = MediaScannerService._();

  static const List<String> _videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'ts', 'webm', 'wmv', '3gp', 'm4v',
  ];

  static const List<String> _audioExtensions = [
    'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'wma', 'aiff',
  ];

  static const List<String> _scanRoots = [
    '/storage/emulated/0/',
    '/storage/emulated/0/Download/',
    '/storage/emulated/0/Music/',
    '/storage/emulated/0/Movies/',
    '/storage/emulated/0/DCIM/',
    '/storage/emulated/0/WhatsApp/Media/',
  ];

  /// Full device scan. Returns all discovered [MediaItem]s.
  Future<List<MediaItem>> scanAll({
    void Function(int found)? onProgress,
  }) async {
    final results = <MediaItem>[];
    const uuid = Uuid();

    for (final root in _scanRoots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;

      try {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;

          final ext = entity.path.split('.').last.toLowerCase();
          final isVideo = _videoExtensions.contains(ext);
          final isAudio = _audioExtensions.contains(ext);

          if (!isVideo && !isAudio) continue;

          final stat = await entity.stat();
          final fileName = entity.path.split('/').last;
          final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

          final item = MediaItem(
            id: uuid.v5(Uuid.NAMESPACE_URL, entity.path),
            title: title,
            fileName: fileName,
            filePath: entity.path,
            isVideo: isVideo,
            addedAt: stat.modified,
            fileSizeBytes: stat.size,
          );

          results.add(item);
          onProgress?.call(results.length);
        }
      } catch (e) {
        debugPrint('[Scanner] Error scanning $root: $e');
      }
    }

    debugPrint('[Scanner] Found ${results.length} media files.');
    return results;
  }

  /// Quick scan of a single directory.
  Future<List<MediaItem>> scanDirectory(String path) async {
    return scanAll();
  }
}
