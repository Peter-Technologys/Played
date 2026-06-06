import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Manages native Picture-in-Picture mode for the video player.
class PipService {
  PipService._();
  static final PipService instance = PipService._();

  static const _channel = MethodChannel('com.played.app/pip');

  /// Enters PiP mode with the given aspect ratio.
  Future<void> enterPip({double aspectRatioWidth = 16, double aspectRatioHeight = 9}) async {
    try {
      await _channel.invokeMethod('enterPip', {
        'width': aspectRatioWidth.toInt(),
        'height': aspectRatioHeight.toInt(),
      });
    } on PlatformException catch (e) {
      debugPrint('[PiP] Failed to enter PiP: ${e.message}');
    }
  }

  /// Returns true if the device supports PiP.
  Future<bool> isPipSupported() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isPipSupported');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
