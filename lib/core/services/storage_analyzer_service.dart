import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageReport {
  final int videoBytes;
  final int audioBytes;
  final int cacheBytes;
  final int otherBytes;
  final int totalBytes;
  final int freeBytes;
  final bool capacityKnown;

  const StorageReport({
    required this.videoBytes,
    required this.audioBytes,
    required this.cacheBytes,
    required this.otherBytes,
    required this.totalBytes,
    required this.freeBytes,
    required this.capacityKnown,
  });

  int get usedBytes => capacityKnown
      ? (totalBytes - freeBytes).clamp(0, totalBytes).toInt()
      : videoBytes + audioBytes + cacheBytes + otherBytes;

  String fmt(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _StorageCapacity {
  final int totalBytes;
  final int freeBytes;

  const _StorageCapacity({required this.totalBytes, required this.freeBytes});

  bool get isKnown => totalBytes > 0 && freeBytes >= 0 && freeBytes <= totalBytes;
}

class StorageAnalyzerService {
  StorageAnalyzerService._();
  static final StorageAnalyzerService instance = StorageAnalyzerService._();

  Future<StorageReport> analyze() async {
    final sizes = await Future.wait<int>([
      _dirSize('/storage/emulated/0/DCIM'),
      _dirSize('/storage/emulated/0/Movies'),
      _dirSize('/storage/emulated/0/Music'),
      _appCacheSize(),
    ]);
    final capacity = await _storageCapacity();

    final videoBytes = sizes[0] + sizes[1];
    final audioBytes = sizes[2];
    final cacheBytes = sizes[3];
    final knownBytes = videoBytes + audioBytes + cacheBytes;

    if (!capacity.isKnown) {
      // Do not invent a device capacity. We can still report the categories
      // OTYA measured, but the UI must label total/free capacity unavailable.
      return StorageReport(
        videoBytes: videoBytes,
        audioBytes: audioBytes,
        cacheBytes: cacheBytes,
        otherBytes: 0,
        totalBytes: knownBytes,
        freeBytes: 0,
        capacityKnown: false,
      );
    }

    final usedStorage = capacity.totalBytes - capacity.freeBytes;
    final otherBytes = (usedStorage - knownBytes).clamp(0, usedStorage).toInt();
    return StorageReport(
      videoBytes: videoBytes,
      audioBytes: audioBytes,
      cacheBytes: cacheBytes,
      otherBytes: otherBytes,
      totalBytes: capacity.totalBytes,
      freeBytes: capacity.freeBytes,
      capacityKnown: true,
    );
  }

  Future<int> purgeCache() async {
    int freed = 0;
    for (final dir in await _cacheDirs()) {
      if (!await dir.exists()) continue;
      try {
        // Collect entities first, then delete — avoids modifying the
        // directory while iterating it (causes ConcurrentModificationError
        // on some Android file systems).
        final entities = await dir.list().toList();
        for (final e in entities) {
          try {
            if (e is File) {
              freed += await e.length();
              await e.delete();
            } else if (e is Directory) {
              freed += await _dirSize(e.path);
              await e.delete(recursive: true);
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[Analyzer] Purge error: $e');
      }
    }
    return freed;
  }

  Future<List<Directory>> _cacheDirs() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      final d = await getApplicationDocumentsDirectory();
      for (final sub in ['cache', 'thumbnails', 'video_thumbs', 'album_art']) {
        final dir = Directory('${d.path}/$sub');
        if (await dir.exists()) dirs.add(dir);
      }
    } catch (_) {}
    return dirs;
  }

  Future<int> _appCacheSize() async {
    int t = 0;
    for (final d in await _cacheDirs()) {
      t += await _dirSize(d.path);
    }
    return t;
  }

  Future<int> _dirSize(String path) async {
    int t = 0;
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return 0;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            t += await e.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return t;
  }

  Future<_StorageCapacity> _storageCapacity() async {
    try {
      final result = await Process.run('df', ['-k', '/storage/emulated/0'])
          .timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) return const _StorageCapacity(totalBytes: 0, freeBytes: 0);

      final lines = (result.stdout as String).trim().split('\n');
      final dataLine = lines.lastWhere(
        (line) => line.contains('/storage/emulated'),
        orElse: () => lines.length >= 2 ? lines.last : '',
      );
      if (dataLine.isEmpty) {
        return const _StorageCapacity(totalBytes: 0, freeBytes: 0);
      }

      // Android df output: Filesystem 1K-blocks Used Available Use% Mounted.
      final parts = dataLine.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) {
        return const _StorageCapacity(totalBytes: 0, freeBytes: 0);
      }

      final totalKb = int.tryParse(parts[1]) ?? 0;
      final availableKb = int.tryParse(parts[3]) ?? -1;
      if (totalKb <= 0 || availableKb < 0 || availableKb > totalKb) {
        return const _StorageCapacity(totalBytes: 0, freeBytes: 0);
      }

      return _StorageCapacity(
        totalBytes: totalKb * 1024,
        freeBytes: availableKb * 1024,
      );
    } catch (error) {
      debugPrint('[Analyzer] Storage capacity unavailable: $error');
      return const _StorageCapacity(totalBytes: 0, freeBytes: 0);
    }
  }
}
