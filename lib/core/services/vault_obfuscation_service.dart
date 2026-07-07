import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// XOR-shifts the first 512 header bytes of a file.
/// Corrupts the format signature so gallery apps cannot scan or play it.
/// XOR is self-inverse — applying the same key twice restores the original.
class VaultObfuscationService {
  VaultObfuscationService._();
  static final VaultObfuscationService instance = VaultObfuscationService._();

  static const List<int> _xorKey = [
    0x4F, 0x54, 0x59, 0x41, 0x50, 0x4C, 0x41, 0x59,
    0x45, 0x52, 0x56, 0x41, 0x55, 0x4C, 0x54, 0x21,
  ];
  static const int _headerSize = 512;

  Future<void> obfuscate({required String sourcePath, required String destPath}) async {
    await Isolate.run(() => _process(sourcePath: sourcePath, destPath: destPath));
    debugPrint('[VaultXOR] Obfuscated: $sourcePath');
  }

  Future<void> restore({required String sourcePath, required String destPath}) async {
    await Isolate.run(() => _process(sourcePath: sourcePath, destPath: destPath));
    debugPrint('[VaultXOR] Restored: $sourcePath');
  }

  Future<Directory> get vaultDirectory async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/.vault_obf');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static void _process({required String sourcePath, required String destPath}) {
    final source = File(sourcePath);
    if (!source.existsSync()) throw FileSystemException('Not found', sourcePath);

    // Stream the file in 4 MB chunks so we never load a 4 GB video into RAM.
    final raf    = source.openSync();
    final dest   = File(destPath);
    dest.parent.createSync(recursive: true);
    final sink   = dest.openWrite();

    try {
      final fileLen   = source.lengthSync();
      int   bytesRead = 0;
      bool  headerDone = false;

      while (bytesRead < fileLen) {
        const chunkSize = 4 * 1024 * 1024; // 4 MB
        final toRead = (fileLen - bytesRead).clamp(0, chunkSize);
        final chunk  = raf.readSync(toRead);
        if (chunk.isEmpty) break;

        if (!headerDone) {
          // XOR only the header portion of this first chunk
          final headerLen = chunk.length < _headerSize ? chunk.length : _headerSize;
          final mutable   = chunk.toList();
          for (var i = 0; i < headerLen; i++) {
            mutable[i] = mutable[i] ^ _xorKey[i % _xorKey.length];
          }
          sink.add(mutable);
          headerDone = true;
        } else {
          sink.add(chunk);
        }
        bytesRead += chunk.length;
      }
    } finally {
      raf.closeSync();
      // closeSync is not available on IOSink; use synchronous flush workaround
      sink.close();
    }
  }
}
