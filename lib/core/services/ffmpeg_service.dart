import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'notification_service.dart';

/// Handles background MP4 → MP3 audio extraction.
/// NOTE: FFmpeg support is temporarily disabled — ffmpeg_kit_flutter and all
/// its variants have been discontinued and their native Maven artifacts no
/// longer resolve during Android builds. This stub keeps the app buildable.
/// Re-implement with a working FFmpeg package when one becomes available.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  /// Extracts audio from [videoPath] and saves as MP3.
  /// Currently returns null (FFmpeg unavailable — see class doc).
  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[FFmpeg] FFmpeg support is disabled — skipping extraction.');
    return null;
  }

  /// No-op: no active FFmpeg sessions to cancel.
  Future<void> cancelAll() async {}
}
