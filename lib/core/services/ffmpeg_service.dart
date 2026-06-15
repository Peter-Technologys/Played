import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'cloudflare_service.dart';

/// Handles FFmpeg operations via Cloudflare Workers + R2.
///
/// The Worker receives the file, runs FFmpeg server-side (no native binary
/// needed on the device), stores the result in R2, and returns a public URL.
/// The result is then downloaded to the device's Documents directory.
///
/// SETUP: Deploy cloudflare/workers/ffmpeg_worker.js and set
///        CloudflareConfig.ffmpegWorkerUrl in cloudflare_config.dart.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  /// Extracts audio from [videoPath] and saves as MP3 to Documents.
  /// Returns the local output path on success, null on failure.
  Future<String?> extractAudio({
    required String videoPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final result = await CloudflareService.instance.runFfmpeg(
        inputFile: File(videoPath),
        operation: FfmpegOperation.extractAudio,
        onProgress: (p, _) => onProgress?.call(p),
      );

      // Download the MP3 from R2 to local Documents
      final dir = await getApplicationDocumentsDirectory();
      final fileName = videoPath.split('/').last.replaceAll(
            RegExp(r'\.[^.]+$'), '.mp3');
      final localPath = '${dir.path}/extracted/$fileName';
      await Directory('${dir.path}/extracted').create(recursive: true);

      await CloudflareService.instance.downloadFromR2(
        result.outputUrl,
        localPath,
        onProgress: onProgress,
      );

      debugPrint('[FFmpeg] Extracted audio saved to: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('[FFmpeg] extractAudio error: $e');
      return null;
    }
  }

  /// Trims [videoPath] from [startSec] to [endSec] and compresses
  /// to fit under 16 MB for WhatsApp Status. Saves to Documents.
  /// Returns the local output path on success, null on failure.
  Future<String?> trimForWhatsApp({
    required String videoPath,
    required double startSec,
    required double endSec,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final result = await CloudflareService.instance.runFfmpeg(
        inputFile: File(videoPath),
        operation: FfmpegOperation.trimForWhatsApp,
        startSec: startSec,
        endSec: endSec,
        onProgress: (p, _) => onProgress?.call(p),
      );

      final dir = await getApplicationDocumentsDirectory();
      final fileName = videoPath.split('/').last.replaceAll(
            RegExp(r'\.[^.]+$'), '_whatsapp.mp4');
      final localPath = '${dir.path}/whatsapp/$fileName';
      await Directory('${dir.path}/whatsapp').create(recursive: true);

      await CloudflareService.instance.downloadFromR2(
        result.outputUrl,
        localPath,
        onProgress: onProgress,
      );

      debugPrint('[FFmpeg] WhatsApp trim saved to: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('[FFmpeg] trimForWhatsApp error: $e');
      return null;
    }
  }

  /// Cancels all active jobs (no-op — Cloudflare Workflows handle timeouts).
  Future<void> cancelAll() async {
    debugPrint('[FFmpeg] cancelAll: jobs are managed by Cloudflare Workflows.');
  }
}
