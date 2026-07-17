import 'dart:io';
import 'dart:math' show min;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';

/// Scans the device for ALL audio and video files regardless of how they
/// were added — USB, file manager, SD card copy, Xender, Bluetooth,
/// WhatsApp, Telegram, ShareIt, AirDrop, Downloads, DCIM, etc.
///
/// Strategy:
///   1. Native MediaStore — audio + video queried in parallel (fast, full metadata).
///   2. Receive dirs — all checked and scanned in parallel (not one by one).
///   3. Full filesystem walk — last resort only if both above return nothing.
class MediaScannerService {
  MediaScannerService._();
  static final MediaScannerService instance = MediaScannerService._();

  // Fix: channel name MUST match MainActivity.kt registration
  static const _channel = MethodChannel('com.otyaplayer.app/media_store');

  static const List<String> _videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'ts', 'webm', 'wmv', '3gp', 'm4v',
    'f4v', 'rm', 'rmvb', 'vob', 'divx', 'xvid',
  ];

  static const List<String> _audioExtensions = [
    'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'wma', 'aiff',
    'amr', 'mid', 'midi', 'ape', 'ac3', 'dts', 'mka',
  ];

  static const Set<String> _skipDirs = {
    'Android', '.thumbnails', '.cache', 'cache', 'obb',
    '.trash', 'lost+found', '.nomedia', 'tmp', 'temp',
    'proc', 'sys', 'dev', // Linux virtual FS — skip on rooted devices
  };

  static const List<String> _receiveDirs = [
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/Video',
    '/storage/emulated/0/Videos',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Bluetooth',
    '/storage/emulated/0/bluetooth',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Audio',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Video',
    '/storage/emulated/0/Telegram/Telegram Audio',
    '/storage/emulated/0/Telegram/Telegram Video',
    '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Audio',
    '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Video',
    '/storage/emulated/0/Xender/video',
    '/storage/emulated/0/Xender/music',
    '/storage/emulated/0/ShareIt',
    '/storage/emulated/0/SHAREit',
    '/storage/emulated/0/Received',
    '/storage/emulated/0/MiDrop',
    '/storage/emulated/0/Zapya',
    '/storage/emulated/0/InShare',
    '/storage/emulated/0/PLAYED',
    '/storage/emulated/0/Download/PLAYED',
  ];

  // PRIMARY: query audio + video in parallel
  Future<List<MediaItem>> _queryMediaStore() async {
    try {
      final both = await Future.wait([
        _channel.invokeListMethod<Map>('queryAudio'),
        _channel.invokeListMethod<Map>('queryVideo'),
      ]);
      final audioRaw = both[0] ?? [];
      final videoRaw = both[1] ?? [];
      final results  = <MediaItem>[];
      for (final raw in [...audioRaw, ...videoRaw]) {
        final path = raw['path'] as String? ?? '';
        if (path.isEmpty) continue;
        final displayName = raw['displayName'] as String? ?? path.split('/').last;
        results.add(MediaItem(
          id:            _stableId(path),
          title:         displayName.replaceAll(RegExp(r'\.[^.]+$'), ''),
          fileName:      displayName,
          filePath:      path,
          isVideo:       raw['isVideo'] as bool? ?? false,
          duration:      (raw['durationMs'] as int? ?? 0) > 0
              ? Duration(milliseconds: raw['durationMs'] as int) : null,
          addedAt:       (raw['dateAdded'] as int? ?? 0) > 0
              ? DateTime.fromMillisecondsSinceEpoch((raw['dateAdded'] as int) * 1000)
              : DateTime.now(),
          fileSizeBytes: raw['size'] as int? ?? 0,
          artist:        raw['artist'] as String?,
          album:         raw['album'] as String?,
          albumArtPath:  raw['albumId'] != null ? 'albumid:${raw['albumId']}' : null,
        ));
      }
      debugPrint('[Scanner] MediaStore: ${results.length} items.');
      return results;
    } on MissingPluginException {
      return [];
    } catch (e) {
      debugPrint('[Scanner] MediaStore failed: $e');
      return [];
    }
  }

  // SUPPLEMENTAL: dirs checked in parallel, scanned in batches of 5
  // to avoid memory pressure from too many concurrent stat() calls on
  // large dirs (e.g. WhatsApp with thousands of files).
  Future<List<MediaItem>> _scanReceiveDirs(Set<String> alreadySeen) async {
    // Check all dirs exist simultaneously
    final existChecks = await Future.wait(
      _receiveDirs.map((p) => Directory(p).exists().catchError((_) => false)),
    );
    final existingDirs = [
      for (var i = 0; i < _receiveDirs.length; i++)
        if (existChecks[i]) _receiveDirs[i],
    ];
    if (existingDirs.isEmpty) return [];

    // Scan in batches of 5 to limit concurrent file I/O
    const batchSize = 5;
    final merged = <MediaItem>[];
    for (var i = 0; i < existingDirs.length; i += batchSize) {
      final batch = existingDirs.sublist(
          i, min(i + batchSize, existingDirs.length));
      final results = await Future.wait(
          batch.map((d) => _scanSingleDir(d, alreadySeen)));
      for (final r in results) merged.addAll(r);
    }
    debugPrint('[Scanner] Receive dirs: ${merged.length} extra items.');
    return merged;
  }

  Future<List<MediaItem>> _scanSingleDir(
      String dirPath, Set<String> alreadySeen) async {
    final results = <MediaItem>[];
    try {
      // Use non-recursive listing — recursive: true on large dirs
      // (e.g. WhatsApp) causes thousands of stat() calls and hangs the scan.
      await for (final entity
          in Directory(dirPath).list(recursive: false, followLinks: false)) {
        if (entity is! File) { continue; }
        final path = entity.path;
        if (alreadySeen.contains(path)) continue;
        final ext = path.split('.').last.toLowerCase();
        final isVideo = _videoExtensions.contains(ext);
        final isAudio = _audioExtensions.contains(ext);
        if (!isVideo && !isAudio) continue;
        try {
          final stat = await entity.stat();
          if (stat.size < 10 * 1024) continue;
          alreadySeen.add(path);
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
    return results;
  }

  // FALLBACK: full filesystem walk
  Future<List<String>> _discoverRoots() async {
    final roots = <String>[];
    const internal = '/storage/emulated/0';
    if (await Directory(internal).exists()) roots.add(internal);
    try {
      await for (final e in Directory('/storage').list()) {
        if (e is Directory) {
          final name = e.path.split('/').last;
          if (name != 'emulated' && name != 'self' && name.contains('-')) {
            roots.add(e.path);
          }
        }
      }
    } catch (_) {}
    return roots;
  }

  Future<List<MediaItem>> _filesystemScan() async {
    final results = <MediaItem>[];
    for (final root in await _discoverRoots()) {
      await _scanDir(Directory(root), results);
    }
    debugPrint('[Scanner] Filesystem fallback: ${results.length} items.');
    return results;
  }

  Future<void> _scanDir(Directory dir, List<MediaItem> out) async {
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          if (_skipDirs.contains(entity.path.split('/').last)) continue;
          await _scanDir(entity, out);
        } else if (entity is File) {
          final ext     = entity.path.split('.').last.toLowerCase();
          final isVideo = _videoExtensions.contains(ext);
          final isAudio = _audioExtensions.contains(ext);
          if (!isVideo && !isAudio) continue;
          try {
            final stat = await entity.stat();
            if (stat.size < 10 * 1024) continue;
            final fileName = entity.path.split('/').last;
            out.add(MediaItem(
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
    } catch (_) {}
  }

  // PUBLIC API

  /// Full scan: MediaStore and receive-dir scan run in parallel, then results
  /// are merged and deduplicated by filePath.
  ///
  /// Running both concurrently ensures files not yet indexed by MediaStore
  /// (e.g. freshly copied via USB, Bluetooth, or file manager on a device
  /// with 5–10 already-indexed items) are never missed.
  ///
  /// Filesystem walk is last resort only if both above return nothing.
  Future<List<MediaItem>> scanAll() async {
    // Run MediaStore first so we can pre-populate alreadySeen with its paths.
    // This prevents _scanReceiveDirs from re-processing files already returned
    // by MediaStore, saving redundant stat() calls on large libraries.
    final storeItems = await _queryMediaStore();

    // Pre-populate alreadySeen so receive-dir scan skips MediaStore files.
    final alreadySeen = {for (final item in storeItems) item.filePath};
    final dirItems = await _scanReceiveDirs(alreadySeen);

    // Deduplicate by filePath — MediaStore is authoritative.
    final seen    = <String>{};
    final merged  = <MediaItem>[];
    for (final item in [...storeItems, ...dirItems]) {
      if (seen.add(item.filePath)) merged.add(item);
    }

    if (merged.isNotEmpty) return merged;

    // Last resort: full filesystem walk (rooted devices, unusual storage layouts)
    return _filesystemScan();
  }

  /// Scans a single directory (folder browser).
  Future<List<MediaItem>> scanDirectory(String path) async {
    final results = <MediaItem>[];
    final dir = Directory(path);
    if (!await dir.exists()) return results;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final ext     = entity.path.split('.').last.toLowerCase();
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
    } catch (_) {}
    return results;
  }

  /// Stable ID derived from the full file path.
  ///
  /// Using the path directly (URL-encoded as a safe Hive key) eliminates the
  /// 32-bit hashCode collision risk: two different paths with the same
  /// hashCode + same length would silently overwrite each other in Hive.
  /// File paths are guaranteed unique on Android's filesystem.
  String _stableId(String path) => Uri.encodeComponent(path);

}
