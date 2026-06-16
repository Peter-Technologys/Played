import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';

/// Scans the device for all audio and video files.
///
/// Strategy:
///   1. Native MediaStore channel (PRIMARY) — reads Android’s media database.
///   2. Filesystem walk (FALLBACK) — used when MediaStore returns nothing
///      OR when files were shared via Xender/Bluetooth/WhatsApp and haven’t
///      been indexed by MediaStore yet.
///
/// The filesystem walk covers ALL common share destinations:
///   /storage/emulated/0/Download
///   /storage/emulated/0/Music
///   /storage/emulated/0/WhatsApp/Media
///   /storage/emulated/0/Xender
///   /storage/emulated/0/Bluetooth
///   /storage/emulated/0/Telegram
///   /storage/emulated/0/ShareIt
///   /storage/emulated/0/DCIM
///   /storage/emulated/0/Movies
class MediaScannerService {
  MediaScannerService._();
  static final MediaScannerService instance = MediaScannerService._();

  static const _channel = MethodChannel('com.petersmart.played/media_store');

  static const List<String> _videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'ts', 'webm', 'wmv', '3gp', 'm4v',
  ];

  static const List<String> _audioExtensions = [
    'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'wma', 'aiff', 'amr',
  ];

  // Directories to always skip
  static const Set<String> _skipDirs = {
    'Android', '.thumbnails', '.cache', 'cache', 'obb',
    '.trash', 'lost+found', '.nomedia',
  };

  // ── PRIMARY: Native MediaStore query ───────────────────────────────────────────────

  Future<List<MediaItem>> _queryMediaStore() async {
    try {
      final audioRaw = await _channel.invokeListMethod<Map>('queryAudio') ?? [];
      final videoRaw = await _channel.invokeListMethod<Map>('queryVideo') ?? [];
      final results  = <MediaItem>[];

      for (final raw in [...audioRaw, ...videoRaw]) {
        final path = raw['path'] as String? ?? '';
        if (path.isEmpty) continue;
        final displayName = raw['displayName'] as String? ?? path.split('/').last;
        final title = displayName.replaceAll(RegExp(r'\.[^.]+$'), '');
        results.add(MediaItem(
          id:            _stableId(path),
          title:         title,
          fileName:      displayName,
          filePath:      path,
          isVideo:       raw['isVideo'] as bool? ?? false,
          duration:      (raw['durationMs'] as int? ?? 0) > 0
              ? Duration(milliseconds: raw['durationMs'] as int)
              : null,
          addedAt:       (raw['dateAdded'] as int? ?? 0) > 0
              ? DateTime.fromMillisecondsSinceEpoch(
                  (raw['dateAdded'] as int) * 1000)
              : DateTime.now(),
          fileSizeBytes: raw['size'] as int? ?? 0,
          artist:        raw['artist'] as String?,
          album:         raw['album'] as String?,
          albumArtPath:  raw['albumId'] != null
              ? 'albumid:${raw['albumId']}'
              : null,
        ));
      }
      debugPrint('[Scanner] MediaStore: ${results.length} items.');
      return results;
    } on MissingPluginException {
      debugPrint('[Scanner] MediaStore channel not available — using fallback.');
      return [];
    } catch (e) {
      debugPrint('[Scanner] MediaStore query failed: $e');
      return [];
    }
  }

  // ── SUPPLEMENTAL: Scan share destinations not yet in MediaStore ────────────────
  // Files shared via Xender, Bluetooth, WhatsApp, Telegram etc. may not
  // appear in MediaStore until the next system scan (which can take minutes).
  // We scan these folders directly so files appear instantly.

  static const List<String> _shareDirs = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Xender',
    '/storage/emulated/0/Xender/video',
    '/storage/emulated/0/Xender/music',
    '/storage/emulated/0/Bluetooth',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Telegram',
    '/storage/emulated/0/Telegram/Telegram Audio',
    '/storage/emulated/0/Telegram/Telegram Video',
    '/storage/emulated/0/ShareIt',
    '/storage/emulated/0/SHAREit',
    '/storage/emulated/0/Received',
    '/storage/emulated/0/PLAYED',
  ];

  Future<List<MediaItem>> _scanShareDirs() async {
    final results = <MediaItem>[];
    final seen    = <String>{};

    for (final dirPath in _shareDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final path = entity.path;
          if (seen.contains(path)) continue;
          final ext = path.split('.').last.toLowerCase();
          final isVideo = _videoExtensions.contains(ext);
          final isAudio = _audioExtensions.contains(ext);
          if (!isVideo && !isAudio) continue;
          try {
            final stat = await entity.stat();
            if (stat.size < 10 * 1024) continue; // skip tiny files
            seen.add(path);
            final fileName = path.split('/').last;
            results.add(MediaItem(
              id:            _stableId(path),
              title:         fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
              fileName:      fileName,
              filePath:      path,
              isVideo:       isVideo,
              addedAt:       stat.modified,
              fileSizeBytes: stat.size,
            ));
          } catch (_) {}
        }
      } catch (_) {}
    }
    debugPrint('[Scanner] Share dirs: ${results.length} extra items.');
    return results;
  }

  // ── FALLBACK: Full filesystem walk ──────────────────────────────────────────────────

  Future<List<String>> _discoverRoots() async {
    final roots = <String>[];
    const internal = '/storage/emulated/0';
    if (await Directory(internal).exists()) roots.add(internal);
    try {
      await for (final entity in Directory('/storage').list()) {
        if (entity is Directory) {
          final name = entity.path.split('/').last;
          if (name != 'emulated' && name != 'self' && name.contains('-')) {
            roots.add(entity.path); // SD card
          }
        }
      }
    } catch (_) {}
    return roots;
  }

  Future<List<MediaItem>> _filesystemScan() async {
    final results = <MediaItem>[];
    final roots   = await _discoverRoots();
    for (final root in roots) {
      await _scanDir(Directory(root), results);
    }
    debugPrint('[Scanner] Filesystem fallback: ${results.length} items.');
    return results;
  }

  Future<void> _scanDir(Directory dir, List<MediaItem> results) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.path.split('/').last;
          if (_skipDirs.contains(name)) continue;
          await _scanDir(entity, results);
        } else if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          final isVideo = _videoExtensions.contains(ext);
          final isAudio = _audioExtensions.contains(ext);
          if (!isVideo && !isAudio) continue;
          try {
            final stat = await entity.stat();
            if (stat.size < 10 * 1024) continue;
            final fileName = entity.path.split('/').last;
            results.add(MediaItem(
              id:            _stableId(entity.path),
              title:         fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
              fileName:      fileName,
              filePath:      entity.path,
              isVideo:       isVideo,
              addedAt:       stat.modified,
              fileSizeBytes: stat.size,
            ));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[Scanner] Error scanning ${dir.path}: $e');
    }
  }

  // ── PUBLIC API ───────────────────────────────────────────────────────────────────────────

  /// Scans all media.
  /// 1. MediaStore (fast, indexed by Android)
  /// 2. Share dirs (Xender, Bluetooth, WhatsApp, Telegram — may not be indexed yet)
  /// 3. Full filesystem walk (fallback if MediaStore returns nothing)
  Future<List<MediaItem>> scanAll({
    void Function(int found)? onProgress,
  }) async {
    final storeResults = await _queryMediaStore();
    // Always also scan share dirs — they may have files not yet in MediaStore
    final shareResults = await _scanShareDirs();

    // Merge: prefer MediaStore data (has metadata), deduplicate by path
    final seen  = <String>{};
    final merged = <MediaItem>[];
    for (final item in [...storeResults, ...shareResults]) {
      if (seen.add(item.filePath)) merged.add(item);
    }

    if (merged.isNotEmpty) return merged;

    // Last resort: full filesystem walk
    return _filesystemScan(onProgress: onProgress);
  }

  /// Scans a single directory (used by folder browser).
  Future<List<MediaItem>> scanDirectory(String path) async {
    final results = <MediaItem>[];
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
            id:            _stableId(entity.path),
            title:         fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
            fileName:      fileName,
            filePath:      entity.path,
            isVideo:       isVideo,
            addedAt:       stat.modified,
            fileSizeBytes: stat.size,
          ));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Scanner] scanDirectory error: $e');
    }
    return results;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────────────

  /// Stable deterministic ID from file path — same file always gets same ID.
  String _stableId(String path) {
    var hash = 0;
    for (final c in path.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
