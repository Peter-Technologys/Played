import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../database/otya_database.dart';
import '../models/media_item.dart';
import '../models/vault_item.dart';

const _kMediaChannel = MethodChannel('com.otyaplayer.app/media_store');

/// Moves media into OTYA's app-private storage and restores it on demand.
///
/// The file is protected by Android's application sandbox and the device's
/// storage encryption. OTYA does not claim a second custom file-encryption
/// layer here. `VaultItem.encryptedPath` is retained as a legacy database field
/// name for schema compatibility until a future migration can rename it safely.
class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  static String _sanitizeFileName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    final clean = base
        .replaceAll('..', '')
        .replaceAll(RegExp(r'[^\w\s.\-]'), '_');
    return clean.isEmpty
        ? 'private_file_${DateTime.now().millisecondsSinceEpoch}'
        : clean;
  }

  static Future<void> _assertWithinVault(String path) async {
    final base = await getApplicationDocumentsDirectory();
    final vaultRoot = Directory('${base.path}/.vault').absolute.path;
    final resolved = File(path).absolute.path;
    final prefix = vaultRoot.endsWith(Platform.pathSeparator)
        ? vaultRoot
        : '$vaultRoot${Platform.pathSeparator}';
    if (resolved != vaultRoot && !resolved.startsWith(prefix)) {
      throw Exception('[Private] Refusing path outside Private storage.');
    }
  }

  /// Never overwrite a different file that appeared at the original location
  /// while an item was inside OTYA Private.
  static Future<String> _availableRestorePath(String originalPath) async {
    if (!await File(originalPath).exists()) return originalPath;

    final separator = Platform.pathSeparator;
    final lastSeparator = originalPath.lastIndexOf(separator);
    final directory = lastSeparator >= 0
        ? originalPath.substring(0, lastSeparator + 1)
        : '';
    final fileName = lastSeparator >= 0
        ? originalPath.substring(lastSeparator + 1)
        : originalPath;
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final extension = dot > 0 ? fileName.substring(dot) : '';

    for (var index = 1; index <= 9999; index++) {
      final candidate = '$directory$stem (restored $index)$extension';
      if (!await File(candidate).exists()) return candidate;
    }

    throw FileSystemException(
      'Could not find a safe restore filename',
      originalPath,
    );
  }

  @visibleForTesting
  static Future<String> findAvailableRestorePathForTest(String originalPath) =>
      _availableRestorePath(originalPath);

  Future<Directory> get _vaultDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/.vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Current Private metadata, newest first. Missing files remain visible so
  /// the UI can explain the storage problem instead of silently losing records.
  List<VaultItem> getAllItems() {
    final items = OtyaDatabase.instance.getAllVaultItems();
    items.sort((a, b) => b.lockedAt.compareTo(a.lockedAt));
    return items;
  }

  /// Total bytes physically present in OTYA Private.
  Future<int> getVaultSize() async {
    var total = 0;
    for (final item in getAllItems()) {
      try {
        await _assertWithinVault(item.encryptedPath);
        final file = File(item.encryptedPath);
        if (await file.exists()) total += await file.length();
      } catch (_) {
        // A corrupt/migrated record should not make the whole Private screen
        // unavailable. The item itself remains visible for user action.
      }
    }
    return total;
  }

  Future<VaultItem> lockItem(MediaItem item) async {
    final dir = await _vaultDir;
    final rawExt = item.fileName.contains('.')
        ? item.fileName.split('.').last
        : 'bin';
    final privateExt = _sanitizeFileName('file.$rawExt').split('.').last;
    final privateId = _sanitizeFileName(item.id);
    final vaultPath = '${dir.path}/$privateId.$privateExt';
    await _assertWithinVault(vaultPath);

    final source = File(item.filePath);
    if (!await source.exists()) {
      throw FileSystemException('Source file not found', item.filePath);
    }

    final copied = await source.copy(vaultPath);
    if (!await copied.exists()) {
      throw FileSystemException('Could not create Private copy', vaultPath);
    }

    final vaultItem = VaultItem(
      mediaId: item.id,
      originalPath: item.filePath,
      encryptedPath: vaultPath,
      lockedAt: DateTime.now(),
      mediaType: item.isVideo ? 'video' : 'audio',
    );

    try {
      await OtyaDatabase.instance.addToVault(vaultItem);
    } catch (_) {
      try {
        await copied.delete();
      } catch (_) {}
      rethrow;
    }

    try {
      await source.delete();
    } catch (_) {
      try {
        await OtyaDatabase.instance.removeFromVault(item.id);
        await copied.delete();
      } catch (_) {}
      throw FileSystemException(
        'Could not move the original media into Private',
        item.filePath,
      );
    }

    try {
      await _kMediaChannel.invokeMethod<void>(
        'triggerScan',
        {'path': item.filePath},
      );
    } catch (_) {}

    debugPrint('[Private] Item moved into app-private storage.');
    return vaultItem;
  }

  Future<void> unlockItem(String mediaId) async {
    final vaultItem = OtyaDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) throw Exception('Private item not found.');

    await _assertWithinVault(vaultItem.encryptedPath);
    final vaultFile = File(vaultItem.encryptedPath);
    if (!await vaultFile.exists()) {
      throw FileSystemException(
        'Private file is missing',
        vaultItem.encryptedPath,
      );
    }

    final restorePath = await _availableRestorePath(vaultItem.originalPath);
    final restoredFile = File(restorePath);

    try {
      await restoredFile.parent.create(recursive: true);
      final restored = await vaultFile.copy(restorePath);
      if (!await restored.exists()) {
        throw FileSystemException('Could not restore media', restorePath);
      }
    } on FileSystemException catch (error) {
      // Android scoped storage can reject direct writes to public media paths
      // even when the file was previously readable. Never delete the Private
      // source or its database record in that case: the protected copy remains
      // recoverable and the UI can retry after a platform-safe restore path is
      // available/authorized.
      debugPrint('[Private] Restore target is not writable: $error');
      try {
        if (await restoredFile.exists()) await restoredFile.delete();
      } catch (_) {}
      throw FileSystemException(
        'OTYA could not restore this item to its original folder. The Private copy was kept safely.',
        restorePath,
      );
    }

    try {
      await vaultFile.delete();
    } catch (_) {
      // Preserve the Private copy as the source of truth if the move cannot be
      // completed atomically. Remove the newly restored duplicate when possible.
      try {
        if (await restoredFile.exists()) await restoredFile.delete();
      } catch (_) {}
      rethrow;
    }

    try {
      await OtyaDatabase.instance.removeFromVault(mediaId);
    } catch (_) {
      // The file has already moved out of Private. Recreate the protected copy
      // before surfacing the metadata failure so the user is never left with a
      // database record pointing to a missing protected file.
      try {
        if (await restoredFile.exists()) {
          await restoredFile.copy(vaultItem.encryptedPath);
          await restoredFile.delete();
        }
      } catch (_) {}
      rethrow;
    }

    try {
      await _kMediaChannel.invokeMethod<void>(
        'triggerScan',
        {'path': restorePath},
      );
    } catch (_) {}

    debugPrint('[Private] Item restored from app-private storage.');
  }

  /// Permanently removes only the app-private copy and its metadata. Refuse to
  /// delete any path that does not resolve inside OTYA Private.
  Future<void> deleteFromVault(String mediaId) async {
    final item = OtyaDatabase.instance.getVaultItem(mediaId);
    if (item == null) return;

    await _assertWithinVault(item.encryptedPath);
    final file = File(item.encryptedPath);
    if (await file.exists()) {
      await file.delete();
    }
    await OtyaDatabase.instance.removeFromVault(mediaId);
    debugPrint('[Private] Protected item permanently deleted.');
  }
}
