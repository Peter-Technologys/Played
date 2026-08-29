import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../database/otya_database.dart';
import '../models/media_item.dart';
import '../models/vault_item.dart';

const _kMediaChannel = MethodChannel('com.otyaplayer.app/media_store');

/// Moves media into OTYA's app-private storage and restores it on demand.
/// Metadata remains protected by the local encrypted/keystore-backed layer.
class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  static String _sanitizeFileName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    final clean = base.replaceAll('..', '').replaceAll(RegExp(r'[^\w\s.\-]'), '_');
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
      throw Exception('[VaultService] Refusing path outside Private storage.');
    }
  }

  Future<Directory> get _vaultDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/.vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<VaultItem> lockItem(MediaItem item) async {
    final dir = await _vaultDir;
    final rawExt = item.fileName.contains('.') ? item.fileName.split('.').last : 'bin';
    final privateExt = _sanitizeFileName('file.$rawExt').split('.').last;
    final privateId = _sanitizeFileName(item.id);
    final vaultPath = '${dir.path}/$privateId.$privateExt';
    await _assertWithinVault(vaultPath);

    final source = File(item.filePath);
    if (!await source.exists()) throw Exception('Source file not found: ${item.filePath}');

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
      try { await copied.delete(); } catch (_) {}
      rethrow;
    }

    try {
      await source.delete();
    } catch (_) {
      try {
        await OtyaDatabase.instance.removeFromVault(item.id);
        await copied.delete();
      } catch (_) {}
      throw FileSystemException('Could not move the original media into Private', item.filePath);
    }

    try {
      await _kMediaChannel.invokeMethod<void>('triggerScan', {'path': item.filePath});
    } catch (_) {}

    debugPrint('[Private] Locked: ${item.title}');
    return vaultItem;
  }

  Future<void> unlockItem(String mediaId) async {
    final vaultItem = OtyaDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) throw Exception('Private item not found: $mediaId');

    await _assertWithinVault(vaultItem.encryptedPath);
    final vaultFile = File(vaultItem.encryptedPath);
    if (!await vaultFile.exists()) {
      throw FileSystemException('Private file is missing', vaultItem.encryptedPath);
    }

    final original = File(vaultItem.originalPath);
    await original.parent.create(recursive: true);
    final restored = await vaultFile.copy(vaultItem.originalPath);
    if (!await restored.exists()) {
      throw FileSystemException('Could not restore media', vaultItem.originalPath);
    }

    await OtyaDatabase.instance.removeFromVault(mediaId);
    try { await vaultFile.delete(); } catch (_) {}

    try {
      await _kMediaChannel.invokeMethod<void>('triggerScan', {'path': vaultItem.originalPath});
    } catch (_) {}

    debugPrint('[Private] Restored: $mediaId');
  }

  Future<void> deleteFromVault(String mediaId) async {
    final vaultItem = OtyaDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) return;

    await _assertWithinVault(vaultItem.encryptedPath);
    final vaultFile = File(vaultItem.encryptedPath);
    if (await vaultFile.exists()) {
      // Best-effort overwrite. Flash storage may remap blocks; OTYA does not
      // represent this as a cryptographic secure-erase guarantee.
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
    debugPrint('[Private] Deleted: $mediaId');
  }

  bool isLocked(String mediaId) => OtyaDatabase.instance.isInVault(mediaId);

  List<VaultItem> getAllItems() => OtyaDatabase.instance.getAllVaultItems();

  Future<int> getVaultSize() async {
    var total = 0;
    for (final item in getAllItems()) {
      final file = File(item.encryptedPath);
      if (await file.exists()) total += await file.length();
    }
    return total;
  }
}
