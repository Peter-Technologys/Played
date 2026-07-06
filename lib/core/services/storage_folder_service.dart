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

///
/// TWO storage areas are created:
///
/// 1. PUBLIC — /storage/emulated/0/PLAYED/
///    Visible in the Files app. Survives app uninstall.
///    User-facing exports go here.
///    Sub-folders:
///      PLAYED/Stems/      — vocal + instrumental stems from Studio
///      PLAYED/Extracted/  — audio extracted from video
///      PLAYED/Trimmed/    — WhatsApp-trimmed clips
///
/// 2. PRIVATE — /Android/data/com.petersmart.played/files/
///    Managed by Android. Cleared when user clears app data.
///    Internal app files go here (cache, temp, thumbnails).
///    Sub-folders:
///      files/cache/       — temporary processing files
///      files/thumbnails/  — generated video thumbnails
///
/// NOTE: files/vault/ is intentionally NOT created here.
///       It is managed exclusively by PlayedDatabase / VaultService.
class StorageFolderService {
  StorageFolderService._();
  static final StorageFolderService instance = StorageFolderService._();

  // ── Public paths (visible in Files app) ──────────────────────────────
  static const String _publicRoot = '/storage/emulated/0/PLAYED';

  Directory? _publicRootDir;
  Directory? _stemsDir;
  Directory? _extractedDir;
  Directory? _trimmedDir;

  // ── Private paths (Android/data/com.petersmart.played/files/) ────────
  Directory? _privateRootDir;
  Directory? _cacheDir;
  Directory? _thumbnailsDir;

  // ─────────────────────────────────────────────────────────────────────
  // PUBLIC directories
  // ─────────────────────────────────────────────────────────────────────

  /// /storage/emulated/0/PLAYED/
  Future<Directory> get publicRoot async {
    if (_publicRootDir != null && await _publicRootDir!.exists()) {
      return _publicRootDir!;
    }
    final dir = Directory(_publicRoot);
    if (!await dir.exists()) await dir.create(recursive: true);
    _publicRootDir = dir;
    return dir;
  }

  /// /storage/emulated/0/PLAYED/Stems/
  Future<Directory> get stemsDirectory async {
    if (_stemsDir != null && await _stemsDir!.exists()) return _stemsDir!;
    final root = await publicRoot;
    final dir = Directory('${root.path}/Stems');
    if (!await dir.exists()) await dir.create();
    _stemsDir = dir;
    return dir;
  }

  /// /storage/emulated/0/PLAYED/Extracted/
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

  /// /storage/emulated/0/PLAYED/Trimmed/
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

  // ─────────────────────────────────────────────────────────────────────
  // PRIVATE directories  (Android/data/com.petersmart.played/files/)
  // ─────────────────────────────────────────────────────────────────────

  /// /Android/data/com.petersmart.played/files/
  ///
  /// Android creates this directory automatically when the app is installed.
  /// [getExternalStorageDirectory] returns exactly:
  ///   /storage/emulated/0/Android/data/com.petersmart.played/files
  Future<Directory> get privateRoot async {
    if (_privateRootDir != null && await _privateRootDir!.exists()) {
      return _privateRootDir!;
    }
    final dir = await getExternalStorageDirectory();
    if (dir == null) throw Exception('External storage not available');
    _privateRootDir = dir;
    return dir;
  }

  /// /Android/data/com.petersmart.played/files/cache/
  Future<Directory> get privateCacheDirectory async {
    if (_cacheDir != null && await _cacheDir!.exists()) return _cacheDir!;
    final root = await privateRoot;
    final dir = Directory('${root.path}/cache');
    if (!await dir.exists()) await dir.create();
    _cacheDir = dir;
    return dir;
  }

  /// /Android/data/com.petersmart.played/files/thumbnails/
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

  // ── Convenience path helpers ──────────────────────────────────────────

  Future<String> pathInStems(String fileName) async =>
      '${(await stemsDirectory).path}/$fileName';

  Future<String> pathInExtracted(String fileName) async =>
      '${(await extractedDirectory).path}/$fileName';

  Future<String> pathInTrimmed(String fileName) async =>
      '${(await trimmedDirectory).path}/$fileName';

  Future<String> pathInCache(String fileName) async =>
      '${(await privateCacheDirectory).path}/$fileName';

  Future<String> pathInThumbnails(String fileName) async =>
      '${(await thumbnailsDirectory).path}/$fileName';

  // ── Startup ───────────────────────────────────────────────────────────

  /// Creates all folders at startup. Safe to call before permissions are
  /// granted — errors are caught and logged, not thrown.
  Future<void> ensureCreated() async {
    // Public folders (require MANAGE_EXTERNAL_STORAGE on Android 11+)
    try {
      await publicRoot;
      await stemsDirectory;
      await extractedDirectory;
      await trimmedDirectory;
      debugPrint('[Storage] Public PLAYED folder ready at $_publicRoot');
    } catch (e) {
      debugPrint('[Storage] Public folder not ready (permission pending?): $e');
    }

    // Private folders (always available, no special permission needed)
    try {
      await privateRoot;
      await privateCacheDirectory;
      await thumbnailsDirectory;
      debugPrint('[Storage] Private app folder ready');
    } catch (e) {
      debugPrint('[Storage] Private folder error: $e');
    }
  }

  // ── Storage info (for Settings screen) ───────────────────────────────

  /// Returns a human-readable summary of all PLAYED storage locations.
  Future<Map<String, String>> storageSummary() async {
    final result = <String, String>{};
    try {
      result['Public (Files app)'] = (await publicRoot).path;
      result['Stems'] = (await stemsDirectory).path;
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
