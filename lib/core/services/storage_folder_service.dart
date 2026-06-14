import 'dart:io';
import 'package:flutter/foundation.dart';

/// Creates and manages the PLAYED folder at the ROOT of internal storage:
///   /storage/emulated/0/PLAYED/
///
/// This makes PLAYED behave like a first-class app — its folder sits
/// alongside Music/, Downloads/, DCIM/ etc. and is immediately visible
/// in the device Files app, not buried in Android/data/.
///
/// Sub-folders:
///   PLAYED/Stems/        — vocal + instrumental stems from Studio
///   PLAYED/Extracted/    — audio extracted from video files
///   PLAYED/Trimmed/      — WhatsApp-trimmed clips
class StorageFolderService {
  StorageFolderService._();
  static final StorageFolderService instance = StorageFolderService._();

  static const String _root = '/storage/emulated/0/PLAYED';

  Directory? _rootDir;

  /// The root PLAYED directory at /storage/emulated/0/PLAYED
  Future<Directory> get rootDirectory async {
    if (_rootDir != null && await _rootDir!.exists()) return _rootDir!;
    final dir = Directory(_root);
    if (!await dir.exists()) await dir.create(recursive: true);
    _rootDir = dir;
    return dir;
  }

  /// /storage/emulated/0/PLAYED/Stems/
  Future<Directory> get stemsDirectory async {
    final root = await rootDirectory;
    final dir = Directory('${root.path}/Stems');
    if (!await dir.exists()) await dir.create();
    return dir;
  }

  /// /storage/emulated/0/PLAYED/Extracted/
  Future<Directory> get extractedDirectory async {
    final root = await rootDirectory;
    final dir = Directory('${root.path}/Extracted');
    if (!await dir.exists()) await dir.create();
    return dir;
  }

  /// /storage/emulated/0/PLAYED/Trimmed/
  Future<Directory> get trimmedDirectory async {
    final root = await rootDirectory;
    final dir = Directory('${root.path}/Trimmed');
    if (!await dir.exists()) await dir.create();
    return dir;
  }

  /// Returns a full file path inside the given sub-folder.
  Future<String> pathInStems(String fileName) async =>
      '${(await stemsDirectory).path}/$fileName';

  Future<String> pathInExtracted(String fileName) async =>
      '${(await extractedDirectory).path}/$fileName';

  Future<String> pathInTrimmed(String fileName) async =>
      '${(await trimmedDirectory).path}/$fileName';

  /// Creates all sub-folders. Call once at startup.
  Future<void> ensureCreated() async {
    try {
      await rootDirectory;
      await stemsDirectory;
      await extractedDirectory;
      await trimmedDirectory;
      debugPrint('[Storage] PLAYED folder ready at $_root');
    } catch (e) {
      // MANAGE_EXTERNAL_STORAGE not yet granted — will retry after permission
      debugPrint('[Storage] Could not create PLAYED folder: $e');
    }
  }
}
