import 'package:flutter/services.dart';

/// Android-native sharing for large local media.
///
/// Uses FileProvider/content:// on Android so a large video does not need to be
/// copied into a temporary cache before the system share sheet opens.
class NativeShareService {
  NativeShareService._();

  static const _channel = MethodChannel('com.otyaplayer.app/share');

  static Future<void> shareFile({
    required String path,
    String? text,
  }) async {
    await _channel.invokeMethod<void>('shareFile', {
      'path': path,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
    });
  }
}
