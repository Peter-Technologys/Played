import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../database/otya_database.dart';
import '../models/vault_item.dart';
import '../models/media_item.dart';

// MethodChannel to trigger MediaStore re-index after vault operations.
// Must match the channel registered in MainActivity.kt.
const _kMediaChannel = MethodChannel('com.otyaplayer.app/media_store');

/// Handles moving media files into and out of the Private Vault.
///
/// Security model:
///   - Files are stored in the app-private directory (inaccessible to other
///     apps without root).
///   - Vault metadata is stored in an AES-256 encrypted Hive box.
///   - File paths are sanitized to prevent path traversal attacks.
///   - The vault key is stored in flutter_secure_storage (Android Keystore).
///
/// Note: File bytes are stored as-is (not re-encrypted at the file level).
/// The combination of app-private storage + AES-256 encrypted metadata
/// provides strong protection on non-rooted devices.
class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  // ── Path sanitization ─────────────────────────────────────────────────────

  /// Sanitizes a file name to prevent path traversal attacks.
  /// Strips directory separators and `..` components, keeping only the
  /// base file name.
  static String _sanitizeFileName(String name) {
    // Extract only the base name — no directory components allowed.
    final base = name.split(RegExp(r'[/\\]')).last;
    // Remove any remaining `..` or `.` sequences.
    final clean = base.replaceAll('..', '').replaceAll(RegExp(r'[^\w\s.\-]'), '_');
    return clean.isEmpty ? 'vault_file_${DateTime.now().millisecondsSinceEpoch}' : clean;
  }

  /// Validates that [path] is within the expected vault directory.
  /// Throws [SecurityException] if the path escapes the vault.
  static Future<void> _assertWithinVault(String path) async {
    final base = await getApplicationDocumentsDirectory();
    final vaultRoot = '${base.path}/.vault';
    final resolved = File(path).absolute.path;
    if (!resolved.startsWith(vaultRoot)) {
      throw Exception(
          '[VaultService] Path traversal detected: $path is outside vault directory.');
    }
  }

  // ── Random nonce helper ───────────────────────────────────────────────────

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  Future<Directory> get _vaultDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/.vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Moves [item] into the vault.
  /// Copies the file to the private vault directory, registers it in Hive,
  /// then deletes the original so it disappears from the media library.
  Future<VaultItem> lockItem(MediaItem item) async {
    final dir = await _vaultDir;
    // Sanitize the file extension to prevent path traversal via crafted IDs.
    final rawExt = item.fileName.contains('.')
        ? item.fileName.split('.').last
        : 'bin';
    final safeExt = _sanitizeFileName('file.$rawExt').split('.').last;
    final safeId  = _sanitizeFileName(item.id);
    final encryptedPath = '${dir.path}/$safeId.$safeExt';
    // Validate the resolved path is within the vault directory.
    await _assertWithinVault(encryptedPath);

    // Copy file into app-private vault directory.
    // Android prevents other apps from reading files here without root.
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

    await OtyaDatabase.instance.addToVault(vaultItem);

    // Delete the original file so it no longer appears in the media library.
    try {
      await source.delete();
    } catch (_) {}

    // Notify MediaStore immediately so the file disappears from the gallery
    // and file managers without waiting for the next periodic scan.
    // Without this, the ghost entry persists until Android re-indexes.
    try {
      await _kMediaChannel.invokeMethod<void>('triggerScan', {'path': item.filePath});
    } catch (_) {}

    debugPrint('[Vault] Locked: ${item.title}');
    return vaultItem;
  }

  /// Restores a vault item back to its original location.
  Future<void> unlockItem(String mediaId) async {
    final vaultItem =
        await OtyaDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) {
      throw Exception('Vault item not found: $mediaId');
    }

    // Validate the vault file path before reading it.
    await _assertWithinVault(vaultItem.encryptedPath);

    final vaultFile = File(vaultItem.encryptedPath);
    if (await vaultFile.exists()) {
      await vaultFile.copy(vaultItem.originalPath);
      await vaultFile.delete();
    }

    await OtyaDatabase.instance.removeFromVault(mediaId);

    // Re-index the restored file in MediaStore so it appears in the library.
    try {
      await _kMediaChannel.invokeMethod<void>('triggerScan', {'path': vaultItem.originalPath});
    } catch (_) {}

    debugPrint('[Vault] Unlocked: $mediaId');
  }

  /// Permanently deletes a vault item without restoring.
  Future<void> deleteFromVault(String mediaId) async {
    final vaultItem =
        await OtyaDatabase.instance.getVaultItem(mediaId);
    if (vaultItem == null) return;

    final vaultFile = File(vaultItem.encryptedPath);
    if (await vaultFile.exists()) {
      // Overwrite with zeros before deleting for secure erase
      final size = await vaultFile.length();
      await vaultFile.writeAsBytes(List<int>.filled(size, 0));
      await vaultFile.delete();
    }

    await OtyaDatabase.instance.removeFromVault(mediaId);
    debugPrint('[Vault] Deleted: $mediaId');
  }

  /// Returns true if [mediaId] is currently in the vault.
  bool isLocked(String mediaId) =>
      OtyaDatabase.instance.isInVault(mediaId);

  /// Returns all vault items.
  Future<List<VaultItem>> getAllItems() =>
      OtyaDatabase.instance.getAllVaultItems();

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
