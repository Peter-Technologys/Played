// Updated import: ffmpeg_kit_flutter_min_gpl was abandoned and removed from
// pub.dev. ffmpeg_kit_flutter_full_gpl is the maintained replacement and
// exposes the same FFmpegKit / ReturnCode API.
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'notification_service.dart';

/// Handles background MP4 → MP3 audio extraction using FFmpeg.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  /// Extracts audio from [videoPath] and saves as MP3.
  /// Shows a local notification with progress.
  /// Returns the output MP3 path on success, null on failure.
  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    final outputDir = await getExternalStorageDirectory();
    if (outputDir == null) return null;

    final fileName = videoPath.split('/').last.replaceAll(
          RegExp(r'\.[^.]+$'),
          '',
        );
    final outputPath = '${outputDir.path}/$fileName.mp3';

    await NotificationService.instance.showProgress(
      id: 1,
      title: 'Extracting Audio',
      body: fileName,
      progress: 0,
    );

    // FFmpeg command: extract audio, encode as 192kbps MP3
    final command =
        '-i "$videoPath" -vn -acodec libmp3lame -ab 192k -ar 44100 "$outputPath" -y';

    debugPrint('[FFmpeg] Running: $command');

    final session = await FFmpegKit.executeAsync(
      command,
      (session) async {
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          await NotificationService.instance.showComplete(
            id: 1,
            title: 'Extraction Complete',
            body: '$fileName.mp3 saved',
          );
          debugPrint('[FFmpeg] Done: $outputPath');
        } else {
          await NotificationService.instance.showError(
            id: 1,
            title: 'Extraction Failed',
            body: fileName,
          );
          debugPrint('[FFmpeg] Failed with code: $code');
        }
      },
      (log) => debugPrint('[FFmpeg Log] ${log.getMessage()}'),
      (statistics) {
        // Estimate progress from time processed
        final timeMs = statistics.getTime();
        if (timeMs > 0) {
          onProgress?.call((timeMs / 1000).clamp(0.0, 1.0));
        }
      },
    );

    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }
    return null;
  }

  /// Cancels all active FFmpeg sessions.
  Future<void> cancelAll() async {
    await FFmpegKit.cancel();
  }
}
