import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../database/played_database.dart';
import '../../models/vault_item.dart';
import '../../models/media_item.dart';

/// Handles moving media files into and out of the encrypted Private Vault.
/// Files are copied into a hidden app-private directory and registered
/// in the AES-256 encrypted Hive vault box.
class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  Future<Directory> get _vaultDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/.vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Moves [item] into the vault.
  /// Copies the file to the private vault directory, then registers it.
  Future<VaultItem> lockItem(MediaItem item) async {
    final dir = await _vaultDir;
    final ext = item.fileName.split('.').last;
    final encryptedPath = '${dir.path}/${item.id}.$ext';

    // Copy file into vault directory
    final source = File(item.filePath);
    if (!await source.exists()) {
      throw Exception('Source file not found: ${item.filePath}');
    }
    await source.copy(encryptedPath);

    final vaultItem = VaultItem(
      mediaId: item.id,
      originalPath: item.filePath,
      encryptedPath: encryptedPath,
      lockedAt: DateTime.now(),
      mediaType: item.isVideo ? 'video' : 'audio',
    );

    await PlayedDatabase.instance.addToVault(vaultItem);
    debugPrint('[Vault] Locked: ${item.title}');
    return vaultItem;
  }

  /// Restores a vault item back to its original location.
  Future<void> unlockItem(String mediaId) async {
    final vaultItem =
        await PlayedDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) {
      throw Exception('Vault item not found: $mediaId');
    }

    final vaultFile = File(vaultItem.encryptedPath);
    if (await vaultFile.exists()) {
      await vaultFile.copy(vaultItem.originalPath);
      await vaultFile.delete();
    }

    await PlayedDatabase.instance.removeFromVault(mediaId);
    debugPrint('[Vault] Unlocked: $mediaId');
  }

  /// Permanently deletes a vault item without restoring.
  Future<void> deleteFromVault(String mediaId) async {
    final vaultItem =
        await PlayedDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) return;

    final vaultFile = File(vaultItem.encryptedPath);
    if (await vaultFile.exists()) {
      // Overwrite with zeros before deleting for secure erase
      final size = await vaultFile.length();
      await vaultFile.writeAsBytes(Uint8List(size));
      await vaultFile.delete();
    }

    await PlayedDatabase.instance.removeFromVault(mediaId);
    debugPrint('[Vault] Deleted: $mediaId');
  }

  /// Returns true if [mediaId] is currently in the vault.
  bool isLocked(String mediaId) =>
      PlayedDatabase.instance.isInVault(mediaId);

  /// Returns all vault items.
  Future<List<VaultItem>> getAllItems() =>
      PlayedDatabase.instance.getAllVaultItems();

  /// Returns the total size of all vault files in bytes.
  Future<int> getVaultSize() async {
    final items = await getAllItems();
    int total = 0;
    for (final item in items) {
      final f = File(item.encryptedPath);
      if (await f.exists()) total += await f.length();
    }
    return total;
  }
}
