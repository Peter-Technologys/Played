import 'dart:io';
import 'dart:math' show min;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../permissions/permission_helper.dart';
import 'new_media_tracker.dart';

Future<List<MediaItem>> _filesystemScanIsolate(List<String> roots) async {
  final results = <MediaItem>[];
  for (final root in roots) {
    await _scanDirIsolate(Directory(root), results);
  }
  return results;
}

const _kVideoExtensions = {
  'mp4', 'mkv', 'avi', 'mov', 'flv', 'ts', 'webm', 'wmv', '3gp', 'm4v',
  'f4v', 'rm', 'rmvb', 'vob', 'divx', 'xvid',
};

const _kAudioExtensions = {
  'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus', 'wma', 'aiff',
  'amr', 'mid', 'midi', 'ape', 'ac3', 'dts', 'mka',
};

const _kSkipDirs = {
  'Android', '.thumbnails', '.cache', 'cache', 'obb',
  '.trash', 'lost+found', '.nomedia', 'tmp', 'temp',
  'proc', 'sys', 'dev',
};

String _stableIdIsolate(String path) => Uri.encodeComponent(path);

Future<void> _scanDirIsolate(Directory dir, List<MediaItem> out) async {
  try {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        if (_kSkipDirs.contains(entity.path.split('/').last)) continue;
        await _scanDirIsolate(entity, out);
      } else if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        final isVideo = _kVideoExtensions.contains(ext);
        final isAudio = _kAudioExtensions.contains(ext);
        if (!isVideo && !isAudio) continue;
        try {
          final stat = await entity.stat();
          if (stat.size < 10 * 1024) continue;
          final fileName = entity.path.split('/').last;
          out.add(MediaItem(
            id: _stableIdIsolate(entity.path),
            title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
            fileName: fileName,
            filePath: entity.path,
            isVideo: isVideo,
            addedAt: stat.modified,
            fileSizeBytes: stat.size,
          ));
        } catch (_) {}
      }
    }
  } catch (_) {}
}

class MediaScannerService {
  MediaScannerService._();
  static final MediaScannerService instance = MediaScannerService._();
  static const _channel = MethodChannel('com.otyaplayer.app/media_store');

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
    '/storage/emulated/0/OTYA',
    '/storage/emulated/0/Download/OTYA',
  ];

  Future<List<MediaItem>> _queryMediaStore() async {
    try {
      final both = await Future.wait([
        _channel.invokeListMethod<Map>('queryAudio'),
        _channel.invokeListMethod<Map>('queryVideo'),
      ]);
      final audioRaw = both[0] ?? [];
      final videoRaw = both[1] ?? [];
      final results = <MediaItem>[];
      for (final raw in [...audioRaw, ...videoRaw]) {
        final path = raw['path'] as String? ?? '';
        if (path.isEmpty) continue;
        final displayName = raw['displayName'] as String? ?? path.split('/').last;
        results.add(MediaItem(
          id: _stableId(path),
          title: displayName.replaceAll(RegExp(r'\.[^.]+$'), ''),
          fileName: displayName,
          filePath: path,
          isVideo: raw['isVideo'] as bool? ?? false,
          duration: (raw['durationMs'] as int? ?? 0) > 0
              ? Duration(milliseconds: raw['durationMs'] as int)
              : null,
          addedAt: (raw['dateAdded'] as int? ?? 0) > 0
              ? DateTime.fromMillisecondsSinceEpoch((raw['dateAdded'] as int) * 1000)
              : DateTime.now(),
          fileSizeBytes: raw['size'] as int? ?? 0,
          artist: raw['artist'] as String?,
          album: raw['album'] as String?,
          albumArtPath: raw['albumId'] != null ? 'albumid:${raw['albumId']}' : null,
          mediaStoreId: raw['id']?.toString(),
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

  Future<List<MediaItem>> _scanReceiveDirs(Set<String> alreadySeen) async {
    final existChecks = await Future.wait(
      _receiveDirs.map((p) => Directory(p).exists().catchError((_) => false)),
    );
    final existingDirs = [
      for (var i = 0; i < _receiveDirs.length; i++)
        if (existChecks[i]) _receiveDirs[i],
    ];
    if (existingDirs.isEmpty) return [];

    const batchSize = 5;
    final merged = <MediaItem>[];
    for (var i = 0; i < existingDirs.length; i += batchSize) {
      final batch = existingDirs.sublist(i, min(i + batchSize, existingDirs.length));
      final results = await Future.wait(batch.map((d) => _scanSingleDir(d, alreadySeen)));
      for (final r in results) merged.addAll(r);
    }
    debugPrint('[Scanner] Receive dirs: ${merged.length} extra items.');
    return merged;
  }

  Future<List<MediaItem>> _scanSingleDir(String dirPath, Set<String> alreadySeen) async {
    final results = <MediaItem>[];
    try {
      await for (final entity in Directory(dirPath).list(recursive: false, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path;
        if (alreadySeen.contains(path)) continue;
        final ext = path.split('.').last.toLowerCase();
        final isVideo = _kVideoExtensions.contains(ext);
        final isAudio = _kAudioExtensions.contains(ext);
        if (!isVideo && !isAudio) continue;
        try {
          final stat = await entity.stat();
          if (stat.size < 10 * 1024) continue;
          alreadySeen.add(path);
          final fileName = path.split('/').last;
          results.add(MediaItem(
            id: _stableId(path),
            title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
            fileName: fileName,
            filePath: path,
            isVideo: isVideo,
            addedAt: stat.modified,
            fileSizeBytes: stat.size,
          ));
        } catch (_) {}
      }
    } catch (_) {}
    return results;
  }

  Future<List<String>> _discoverRoots() async {
    final roots = <String>[];
    const internal = '/storage/emulated/0';
    if (await Directory(internal).exists()) roots.add(internal);
    try {
      await for (final e in Directory('/storage').list()) {
        if (e is Directory) {
          final name = e.path.split('/').last;
          if (name != 'emulated' && name != 'self' && name.contains('-')) roots.add(e.path);
        }
      }
    } catch (_) {}
    return roots;
  }

  Future<List<MediaItem>> _filesystemScan() async {
    final roots = await _discoverRoots();
    final results = await compute(_filesystemScanIsolate, roots);
    debugPrint('[Scanner] Filesystem fallback: ${results.length} items.');
    return results;
  }

  Future<List<MediaItem>> _finalize(List<MediaItem> items) async {
    await NewMediaTracker.instance.reconcile(items);
    return items;
  }

  Future<List<MediaItem>> scanAll() async {
    final hasPermission = await PermissionHelper.hasMediaPermissions();
    if (!hasPermission) {
      final granted = await PermissionHelper.requestMediaPermissions();
      if (!granted) {
        throw Exception('permission: Storage permission denied. Grant access to scan your media library.');
      }
    }

    final storeItems = await _queryMediaStore();
    final alreadySeen = {for (final item in storeItems) item.filePath};
    final dirItems = await _scanReceiveDirs(alreadySeen);
    final seen = <String>{};
    final merged = <MediaItem>[];
    for (final item in [...storeItems, ...dirItems]) {
      if (seen.add(item.filePath)) merged.add(item);
    }
    if (merged.isNotEmpty) return _finalize(merged);
    try {
      return _finalize(await _filesystemScan());
    } catch (e) {
      debugPrint('[Scanner] Filesystem fallback failed: $e');
      return _finalize(const <MediaItem>[]);
    }
  }

  Future<List<MediaItem>> scanDirectory(String path) async {
    final results = <MediaItem>[];
    final dir = Directory(path);
    if (!await dir.exists()) return results;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final ext = entity.path.split('.').last.toLowerCase();
        final isVideo = _kVideoExtensions.contains(ext);
        final isAudio = _kAudioExtensions.contains(ext);
        if (!isVideo && !isAudio) continue;
        try {
          final stat = await entity.stat();
          if (stat.size < 10 * 1024) continue;
          final fileName = entity.path.split('/').last;
          results.add(MediaItem(
            id: _stableId(entity.path),
            title: fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
            fileName: fileName,
            filePath: entity.path,
            isVideo: isVideo,
            addedAt: stat.modified,
            fileSizeBytes: stat.size,
          ));
        } catch (_) {}
      }
    } catch (_) {}
    return results;
  }

  String _stableId(String path) => Uri.encodeComponent(path);
}
