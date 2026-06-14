import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Handles FFmpeg operations: audio extraction and video trimming.
///
/// NOTE: ffmpeg_kit_flutter has been removed from pubspec.yaml because its
/// native Maven artifacts (com.arthenica:ffmpeg-kit-*:6.0-2) are discontinued
/// and cannot be resolved during Android builds.
/// These methods return null until a working replacement is integrated.
/// See: https://github.com/arthenica/ffmpeg-kit/issues/367
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  /// Extracts audio from [videoPath] and saves as MP3 to Downloads.
  /// Returns the output path on success, null on failure.
  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[FFmpeg] extractAudio: ffmpeg_kit_flutter is not available. '
        'Returning null until a replacement is integrated.');
    return null;
  }

  /// Trims [videoPath] from [startSec] to [endSec] and compresses
  /// to fit under 16 MB for WhatsApp Status. Saves to Downloads.
  /// Returns the output path on success, null on failure.
  Future<String?> trimForWhatsApp({
    required String videoPath,
    required double startSec,
    required double endSec,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[FFmpeg] trimForWhatsApp: ffmpeg_kit_flutter is not available. '
        'Returning null until a replacement is integrated.');
    return null;
  }

  /// Cancels all active FFmpeg sessions.
  Future<void> cancelAll() async {
    debugPrint('[FFmpeg] cancelAll: ffmpeg_kit_flutter is not available.');
  }
}
