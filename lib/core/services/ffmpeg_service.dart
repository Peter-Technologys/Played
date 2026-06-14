import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Handles FFmpeg operations: audio extraction and video trimming.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  /// Extracts audio from [videoPath] and saves as MP3 to Downloads.
  /// Returns the output path on success, null on failure.
  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      final name = videoPath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final outPath = '${dir.path}/$name.mp3';

      onProgress?.call(0.1);

      // Enable statistics callback for progress tracking
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final duration = stats.getTime();
        if (duration > 0) {
          onProgress?.call((duration / 1000).clamp(0.0, 1.0));
        }
      });

      final session = await FFmpegKit.execute(
        '-y -i "$videoPath" -vn -acodec libmp3lame -q:a 2 "$outPath"',
      );
      final rc = await session.getReturnCode();
      FFmpegKitConfig.disableStatistics();

      if (ReturnCode.isSuccess(rc)) {
        onProgress?.call(1.0);
        debugPrint('[FFmpeg] Extracted audio to $outPath');
        return outPath;
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('[FFmpeg] extractAudio failed: $logs');
        return null;
      }
    } catch (e) {
      debugPrint('[FFmpeg] extractAudio error: $e');
      return null;
    }
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
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      final name = videoPath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final outPath = '${dir.path}/${name}_wa.mp4';
      final duration = endSec - startSec;

      onProgress?.call(0.05);

      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final ms = stats.getTime();
        if (ms > 0 && duration > 0) {
          onProgress?.call((ms / 1000 / duration).clamp(0.0, 0.95));
        }
      });

      // Target bitrate to stay under 16 MB for the clip duration.
      // 16 MB = 131072 kbits. Reserve 128 kbps for audio.
      final videoBitrate = ((131072 / duration) - 128).clamp(200, 2000).toInt();

      final session = await FFmpegKit.execute(
        '-y -ss $startSec -i "$videoPath" -t $duration '
        '-c:v libx264 -b:v ${videoBitrate}k -c:a aac -b:a 128k '
        '-vf scale=720:-2 -movflags +faststart "$outPath"',
      );
      final rc = await session.getReturnCode();
      FFmpegKitConfig.disableStatistics();

      if (ReturnCode.isSuccess(rc)) {
        onProgress?.call(1.0);
        debugPrint('[FFmpeg] Trimmed to $outPath');
        return outPath;
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('[FFmpeg] trimForWhatsApp failed: $logs');
        return null;
      }
    } catch (e) {
      debugPrint('[FFmpeg] trimForWhatsApp error: $e');
      return null;
    }
  }

  /// Cancels all active FFmpeg sessions.
  Future<void> cancelAll() async {
    await FFmpegKit.cancel();
  }
}
