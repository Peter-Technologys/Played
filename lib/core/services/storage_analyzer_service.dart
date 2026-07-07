import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageReport {
  final int videoBytes, audioBytes, cacheBytes, otherBytes, totalBytes;
  const StorageReport({required this.videoBytes, required this.audioBytes,
      required this.cacheBytes, required this.otherBytes, required this.totalBytes});
  int get usedBytes => videoBytes + audioBytes + cacheBytes + otherBytes;
  int get freeBytes => (totalBytes - usedBytes).clamp(0, totalBytes);
  String fmt(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class StorageAnalyzerService {
  StorageAnalyzerService._();
  static final StorageAnalyzerService instance = StorageAnalyzerService._();

  Future<StorageReport> analyze() async {
    final results = await Future.wait([
      _dirSize('/storage/emulated/0/DCIM'),
      _dirSize('/storage/emulated/0/Movies'),
      _dirSize('/storage/emulated/0/Music'),
      _appCacheSize(),
      _totalStorage(),
    ]);
    final videoBytes = results[0] + results[1];
    final audioBytes = results[2];
    final cacheBytes = results[3];
    final totalBytes = results[4];
    final otherBytes = (totalBytes - videoBytes - audioBytes - cacheBytes).clamp(0, totalBytes);
    return StorageReport(videoBytes: videoBytes, audioBytes: audioBytes,
        cacheBytes: cacheBytes, otherBytes: otherBytes, totalBytes: totalBytes);
  }

  Future<int> purgeCache() async {
    int freed = 0;
    for (final dir in await _cacheDirs()) {
      if (!await dir.exists()) continue;
      try {
        await for (final e in dir.list()) {
          try {
            if (e is File) { freed += await e.length(); await e.delete(); }
            else if (e is Directory) { freed += await _dirSize(e.path); await e.delete(recursive: true); }
          } catch (_) {}
        }
      } catch (e) { debugPrint('[Analyzer] Purge error: $e'); }
    }
    return freed;
  }

  Future<List<Directory>> _cacheDirs() async {
    final dirs = <Directory>[];
    try { dirs.add(await getTemporaryDirectory()); } catch (_) {}
    try {
      final d = await getApplicationDocumentsDirectory();
      for (final sub in ['cache','thumbnails','video_thumbs','album_art']) {
        final dir = Directory('${d.path}/$sub');
        if (await dir.exists()) dirs.add(dir);
      }
    } catch (_) {}
    return dirs;
  }

  Future<int> _appCacheSize() async {
    int t = 0;
    for (final d in await _cacheDirs()) t += await _dirSize(d.path);
    return t;
  }

  Future<int> _dirSize(String path) async {
    int t = 0;
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return 0;
      await for (final e in dir.list(recursive: true, followLinks: false))
        if (e is File) try { t += await e.length(); } catch (_) {}
    } catch (_) {}
    return t;
  }

  Future<int> _totalStorage() async {
    try {
      final r = await Process.run('df', ['/storage/emulated/0']);
      if (r.exitCode == 0) {
        final lines = (r.stdout as String).trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) return (int.tryParse(parts[1]) ?? 0) * 1024;
        }
      }
    } catch (_) {}
    return 64 * 1024 * 1024 * 1024;
  }
}
