import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../database/otya_database.dart';
import '../models/media_item.dart';
import '../models/vault_item.dart';

const _kMediaChannel = MethodChannel('com.otyaplayer.app/media_store');

/// Moves media into OTYA's app-private Safe storage and restores it on demand.
/// Metadata remains protected by the encrypted local database/keystore layer.
class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  static String _sanitizeFileName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    final clean = base
        .replaceAll('..', '')
        .replaceAll(RegExp(r'[^\w\s.\-]'), '_');
    return clean.isEmpty
        ? 'vault_file_${DateTime.now().millisecondsSinceEpoch}'
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
      throw Exception('[VaultService] Refusing path outside Safe storage.');
    }
  }

  Future<Directory> get _vaultDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/.vault');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<VaultItem> lockItem(MediaItem item) async {
    final dir = await _vaultDir;
    final rawExt = item.fileName.contains('.')
        ? item.fileName.split('.').last
        : 'bin';
    final safeExt = _sanitizeFileName('file.$rawExt').split('.').last;
    final safeId = _sanitizeFileName(item.id);
    final vaultPath = '${dir.path}/$safeId.$safeExt';
    await _assertWithinVault(vaultPath);

    final source = File(item.filePath);
    if (!await source.exists()) {
      throw Exception('Source file not found: ${item.filePath}');
    }

    // Copy first and verify the destination exists before deleting the source.
    final copied = await source.copy(vaultPath);
    if (!await copied.exists()) {
      throw FileSystemException('Could not create Safe copy', vaultPath);
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
      // Do not strand a copied file when metadata registration fails.
      try {
        await copied.delete();
      } catch (_) {}
      rethrow;
    }

    try {
      await source.delete();
    } catch (e) {
      // Roll back the Safe registration if the original cannot be removed;
      // otherwise the user could unknowingly keep two copies.
      try {
        await OtyaDatabase.instance.removeFromVault(item.id);
        await copied.delete();
      } catch (_) {}
      throw FileSystemException('Could not hide original media file', item.filePath);
    }

    try {
      await _kMediaChannel.invokeMethod<void>(
        'triggerScan',
        {'path': item.filePath},
      );
    } catch (_) {}

    debugPrint('[Vault] Locked: ${item.title}');
    return vaultItem;
  }

  Future<void> unlockItem(String mediaId) async {
    final vaultItem = OtyaDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) {
      throw Exception('Safe item not found: $mediaId');
    }

    await _assertWithinVault(vaultItem.encryptedPath);
    final vaultFile = File(vaultItem.encryptedPath);
    if (!await vaultFile.exists()) {
      throw FileSystemException('Safe file is missing', vaultItem.encryptedPath);
    }

    final original = File(vaultItem.originalPath);
    await original.parent.create(recursive: true);
    final restored = await vaultFile.copy(vaultItem.originalPath);
    if (!await restored.exists()) {
      throw FileSystemException('Could not restore media', vaultItem.originalPath);
    }

    // Metadata is removed only after the restored copy is confirmed.
    await OtyaDatabase.instance.removeFromVault(mediaId);
    try {
      await vaultFile.delete();
    } catch (_) {
      // A private duplicate is safer than deleting the only restored copy.
    }

    try {
      await _kMediaChannel.invokeMethod<void>(
        'triggerScan',
        {'path': vaultItem.originalPath},
      );
    } catch (_) {}

    debugPrint('[Vault] Unlocked: $mediaId');
  }

  Future<void> deleteFromVault(String mediaId) async {
    final vaultItem = OtyaDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) return;

    await _assertWithinVault(vaultItem.encryptedPath);
    final vaultFile = File(vaultItem.encryptedPath);
    if (await vaultFile.exists()) {
      // Best-effort overwrite. Flash storage may remap blocks, so this is not
      // presented as a cryptographic secure erase guarantee.
      try {
        final size = await vaultFile.length();
        const chunkSize = 1024 * 1024;
        final raf = await vaultFile.open(mode: FileMode.write);
        try {
          var remaining = size;
          final zeroChunk = List<int>.filled(chunkSize, 0);
          while (remaining > 0) {
            final count = remaining > chunkSize ? chunkSize : remaining;
            await raf.writeFrom(zeroChunk, 0, count);
            remaining -= count;
          }
          await raf.flush();
        } finally {
          await raf.close();
        }
      } catch (_) {}
      await vaultFile.delete();
    }

    await OtyaDatabase.instance.removeFromVault(mediaId);
    debugPrint('[Vault] Deleted: $mediaId');
  }

  bool isLocked(String mediaId) => OtyaDatabase.instance.isInVault(mediaId);

  List<VaultItem> getAllItems() => OtyaDatabase.instance.getAllVaultItems();

  Future<int> getVaultSize() async {
    final items = getAllItems();
    var total = 0;
    for (final item in items) {
      final file = File(item.encryptedPath);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }
}
