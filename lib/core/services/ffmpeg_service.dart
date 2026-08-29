import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Local media processing used by OTYA Converter and contextual video tools.
///
/// These operations use the Android native channel and do not require an
/// account, AI, Cloudflare, or an upload of the user's media file.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  static const _channel = MethodChannel('com.otyaplayer.app/ffmpeg');

  /// Extracts an audio track from a local video file.
  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      final result = await _channel.invokeMethod<String>(
        'extractAudio',
        {'path': videoPath},
      );
      onProgress?.call(1.0);
      return result;
    } catch (error) {
      debugPrint('[OTYA Converter] extract audio failed: ${error.runtimeType}');
      return null;
    }
  }

  /// Trims a local video to the requested time range.
  Future<String?> trimVideo({
    required String videoPath,
    required double startSec,
    required double endSec,
    void Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      final result = await _channel.invokeMethod<String>(
        'trimVideo',
        {
          'path': videoPath,
          'startMs': (startSec * 1000).toInt(),
          'endMs': (endSec * 1000).toInt(),
        },
      );
      onProgress?.call(1.0);
      return result;
    } catch (error) {
      debugPrint('[OTYA Tools] trim video failed: ${error.runtimeType}');
      return null;
    }
  }

  /// Compatibility name used by older UI code.
  Future<String?> trimForWhatsApp({
    required String videoPath,
    required double startSec,
    required double endSec,
    void Function(double progress)? onProgress,
  }) =>
      trimVideo(
        videoPath: videoPath,
        startSec: startSec,
        endSec: endSec,
        onProgress: onProgress,
      );

  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
  }
}
