import 'package:flutter/foundation.dart';

/// FFmpeg is not available — ffmpeg_kit_flutter is discontinued and removed
/// from pubspec.yaml. These methods return null gracefully so the app
/// compiles and runs. Re-implement when a working package is available.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[FFmpeg] extractAudio: ffmpeg_kit_flutter not available.');
    return null;
  }

  Future<String?> trimForWhatsApp({
    required String videoPath,
    required double startSec,
    required double endSec,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[FFmpeg] trimForWhatsApp: ffmpeg_kit_flutter not available.');
    return null;
  }

  Future<void> cancelAll() async {}
}
