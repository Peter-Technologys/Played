import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages ALL storage locations for OTYA Player.
///
/// PUBLIC  -> /storage/emulated/0/OTYA Player/  (visible in Files app)
/// PRIVATE -> /Android/data/com.otyaplayer.app/files/  (app-private)
class StorageFolderService {
  StorageFolderService._();
  static final StorageFolderService instance = StorageFolderService._();

  // Renamed from /PLAYED to /OTYA Player to match the app brand.
  // Files the app creates on the user device now show the correct name.
  static const String _publicRoot = '/storage/emulated/0/OTYA Player';

  Directory? _publicRootDir;
  Directory? _extractedDir;
  Directory? _trimmedDir;
  Directory? _privateRootDir;
  Directory? _cacheDir;
  Directory? _thumbnailsDir;

  Future<Directory> get publicRoot async {
    if (_publicRootDir != null && await _publicRootDir!.exists()) {
      return _publicRootDir!;
    }
    final dir = Directory(_publicRoot);
    if (!await dir.exists()) await dir.create(recursive: true);
    _publicRootDir = dir;
    return dir;
  }

  Future<Directory> get extractedDirectory async {
    if (_extractedDir != null && await _extractedDir!.exists()) {
      return _extractedDir!;
    }
    final root = await publicRoot;
    final dir = Directory('${root.path}/Extracted');
    if (!await dir.exists()) await dir.create();
    _extractedDir = dir;
    return dir;
  }

  Future<Directory> get trimmedDirectory async {
    if (_trimmedDir != null && await _trimmedDir!.exists()) {
      return _trimmedDir!;
    }
    final root = await publicRoot;
    final dir = Directory('${root.path}/Trimmed');
    if (!await dir.exists()) await dir.create();
    _trimmedDir = dir;
    return dir;
  }

  Future<Directory> get privateRoot async {
    if (_privateRootDir != null && await _privateRootDir!.exists()) {
      return _privateRootDir!;
    }
    final dir = await getExternalStorageDirectory();
    if (dir == null) throw Exception('External storage not available');
    _privateRootDir = dir;
    return dir;
  }

  Future<Directory> get privateCacheDirectory async {
    if (_cacheDir != null && await _cacheDir!.exists()) return _cacheDir!;
    final root = await privateRoot;
    final dir = Directory('${root.path}/cache');
    if (!await dir.exists()) await dir.create();
    _cacheDir = dir;
    return dir;
  }

  Future<Directory> get thumbnailsDirectory async {
    if (_thumbnailsDir != null && await _thumbnailsDir!.exists()) {
      return _thumbnailsDir!;
    }
    final root = await privateRoot;
    final dir = Directory('${root.path}/thumbnails');
    if (!await dir.exists()) await dir.create();
    _thumbnailsDir = dir;
    return dir;
  }

  Future<String> pathInExtracted(String fileName) async =>
      '${(await extractedDirectory).path}/$fileName';

  Future<String> pathInTrimmed(String fileName) async =>
      '${(await trimmedDirectory).path}/$fileName';

  Future<String> pathInCache(String fileName) async =>
      '${(await privateCacheDirectory).path}/$fileName';

  Future<String> pathInThumbnails(String fileName) async =>
      '${(await thumbnailsDirectory).path}/$fileName';

  Future<void> ensureCreated() async {
    try {
      await publicRoot;
      await extractedDirectory;
      await trimmedDirectory;
      debugPrint('[Storage] Public OTYA Player folder ready at $_publicRoot');
    } catch (e) {
      debugPrint('[Storage] Public folder not ready (permission pending?): $e');
    }
    try {
      await privateRoot;
      await privateCacheDirectory;
      await thumbnailsDirectory;
      debugPrint('[Storage] Private app folder ready');
    } catch (e) {
      debugPrint('[Storage] Private folder error: $e');
    }
  }

  Future<Map<String, String>> storageSummary() async {
    final result = <String, String>{};
    try {
      result['Public (Files app)'] = (await publicRoot).path;
      result['Extracted Audio'] = (await extractedDirectory).path;
      result['Trimmed Clips'] = (await trimmedDirectory).path;
    } catch (_) {}
    try {
      result['App Data'] = (await privateRoot).path;
      result['Cache'] = (await privateCacheDirectory).path;
      result['Thumbnails'] = (await thumbnailsDirectory).path;
    } catch (_) {}
    return result;
  }
}
