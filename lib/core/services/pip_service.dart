import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Manages native Picture-in-Picture mode for the video player.
class PipService {
  PipService._();
  static final PipService instance = PipService._();

  // Channel name must match MainActivity.kt registration.
  static const _channel = MethodChannel('com.otyaplayer.app/pip');

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
      final result = await _channel.invokeMethod<bool>('isPipSupported');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Notifies the native side whether video is actively playing.
  /// Call this whenever the video player starts or stops so that
  /// [onUserLeaveHint] in MainActivity can decide whether to auto-enter PiP.
  /// Previously MainActivity used [AudioManager.isMusicActive] which is
  /// audio-only and fails for muted or silent videos.
  Future<void> setVideoPlaying({required bool playing}) async {
    try {
      await _channel.invokeMethod('setVideoPlaying', {'playing': playing});
    } on PlatformException catch (e) {
      debugPrint('[PiP] setVideoPlaying failed: ${e.message}');
    }
  }
}
