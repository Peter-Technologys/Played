import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';

/// Scans the device for ALL audio and video files regardless of how they
/// were added — USB, file manager, SD card copy, Xender, Bluetooth,
/// WhatsApp, Telegram, ShareIt, AirDrop, Downloads, DCIM, etc.
///
/// Strategy (runs in order, results merged):
///   1. Native MediaStore query — fast, has full metadata.
///   2. Direct scan of every known share/receive folder — catches files
///      not yet indexed by MediaStore (can take minutes after copy).
///   3. Full filesystem walk — last resort fallback.
class MediaScannerService {
  MediaScannerService._();
  static final MediaScannerService instance = MediaScannerService._();

  static const _channel = MethodChannel('com.petersmart.played/media_store');

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
  };

  // Every folder where files can land from ANY sharing method
  static const List<String> _receiveDirs = [
    // Standard locations
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/Video',
    '/storage/emulated/0/Videos',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Ringtones',
    '/storage/emulated/0/Notifications',
    '/storage/emulated/0/Alarms',
    '/storage/emulated/0/Podcasts',
    '/storage/emulated/0/Audiobooks',
    // Xender
    '/storage/emulated/0/Xender',
    '/storage/emulated/0/Xender/video',
    '/storage/emulated/0/Xender/music',
    '/storage/emulated/0/Xender/file',
    // Bluetooth
    '/storage/emulated/0/Bluetooth',
    '/storage/emulated/0/bluetooth',
    // WhatsApp (old + new scoped storage paths)
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    // WhatsApp Business
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Audio',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Video',
    // Telegram
    '/storage/emulated/0/Telegram',
    '/storage/emulated/0/Telegram/Telegram Audio',
    '/storage/emulated/0/Telegram/Telegram Video',
    '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Audio',
    '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Video',
    // ShareIt / SHAREit
    '/storage/emulated/0/ShareIt',
    '/storage/emulated/0/SHAREit',
    '/storage/emulated/0/ShareIt/music',
    '/storage/emulated/0/ShareIt/video',
    // Send Anywhere
    '/storage/emulated/0/Send Anywhere',
    // Files by Google / Mi Drop / Zapya / InShare
    '/storage/emulated/0/Received',
    '/storage/emulated/0/MiDrop',
    '/storage/emulated/0/Zapya',
    '/storage/emulated/0/InShare',
    // PLAYED own folder (AirDrop receive)
    '/storage/emulated/0/PLAYED',
    '/storage/emulated/0/Download/PLAYED',
  ];

  // ── PRIMARY: Native MediaStore ────────────────────────────────────────

  Future<List<MediaItem>> _queryMediaStore() async {
    try {
      final audioRaw = await _channel.invokeListMethod<Map>('queryAudio') ?? [];
      final videoRaw = await _channel.invokeListMethod<Map>('queryVideo') ?? [];
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

  // ── SUPPLEMENTAL: Direct folder scan ─────────────────────────────────
  // Catches files not yet indexed by MediaStore.

  Future<List<MediaItem>> _scanReceiveDirs() async {
    final results = <MediaItem>[];
    final seen    = <String>{};
    for (final dirPath in _receiveDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final path = entity.path;
          if (seen.contains(path)) continue;
          final ext     = path.split('.').last.toLowerCase();
          final isVideo = _videoExtensions.contains(ext);
          final isAudio = _audioExtensions.contains(ext);
          if (!isVideo && !isAudio) continue;
          try {
            final stat = await entity.stat();
            if (stat.size < 10 * 1024) continue;
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
    debugPrint('[Scanner] Receive dirs: ${results.length} extra items.');
    return results;
  }

  // ── FALLBACK: Full filesystem walk ────────────────────────────────────

  Future<List<String>> _discoverRoots() async {
    final roots = <String>[];
    const internal = '/storage/emulated/0';
    if (await Directory(internal).exists()) roots.add(internal);
    try {
      await for (final e in Directory('/storage').list()) {
        if (e is Directory) {
          final name = e.path.split('/').last;
          if (name != 'emulated' && name != 'self' && name.contains('-')) {
            roots.add(e.path); // SD card
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

  // ── PUBLIC API ────────────────────────────────────────────────────────

  /// Full scan: MediaStore + all receive dirs + filesystem fallback.
  /// Works 100% offline. No internet needed.
  Future<List<MediaItem>> scanAll() async {
    final store  = await _queryMediaStore();
    final extra  = await _scanReceiveDirs();

    // Merge, deduplicate by path, prefer MediaStore entries (have metadata)
    final seen   = <String>{};
    final merged = <MediaItem>[];
    for (final item in [...store, ...extra]) {
      if (seen.add(item.filePath)) merged.add(item);
    }
    if (merged.isNotEmpty) return merged;
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

  // ── Helpers ───────────────────────────────────────────────────────────

  String _stableId(String path) {
    var hash = 0;
    for (final c in path.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
