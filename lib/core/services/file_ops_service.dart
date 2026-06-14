import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Dart wrapper around the native file_ops MethodChannel.
class FileOpsService {
  FileOpsService._();
  static final FileOpsService instance = FileOpsService._();

  static const _ch = MethodChannel('com.petersmart.played/file_ops');

  Future<bool> deleteFile(String path) async {
    try {
      return await _ch.invokeMethod<bool>('deleteFile', {'path': path}) ?? false;
    } catch (e) {
      debugPrint('[FileOps] deleteFile: $e');
      return false;
    }
  }

  Future<String?> renameFile(String path, String newName) async {
    try {
      return await _ch.invokeMethod<String>(
          'renameFile', {'path': path, 'newName': newName});
    } catch (e) {
      debugPrint('[FileOps] renameFile: $e');
      return null;
    }
  }
}
