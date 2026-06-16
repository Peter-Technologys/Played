import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// FFmpeg service — uses the Cloudflare Worker for server-side processing
/// when online, and falls back to a graceful error when offline.
///
/// WhatsApp Trimmer and Extract Audio both route through the Cloudflare
/// ffmpeg_worker.js which runs FFmpeg server-side and returns a download URL.
///
/// For fully offline trimming, the native MediaStore trim API is used
/// on Android 10+ (API 29+) via a platform channel.
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  static const _channel = MethodChannel('com.petersmart.played/ffmpeg');

  /// Extracts audio from a video file.
  /// Uses native MediaMetadataRetriever on Android (offline, no FFmpeg needed).
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
    } catch (e) {
      debugPrint('[FFmpeg] extractAudio error: $e');
      return null;
    }
  }

  /// Trims a video to the given range and compresses for WhatsApp.
  /// Uses native MediaMuxer on Android 10+ (offline, no FFmpeg needed).
  Future<String?> trimForWhatsApp({
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
          'path':     videoPath,
          'startMs':  (startSec * 1000).toInt(),
          'endMs':    (endSec   * 1000).toInt(),
        },
      );
      onProgress?.call(1.0);
      return result;
    } catch (e) {
      debugPrint('[FFmpeg] trimForWhatsApp error: $e');
      return null;
    }
  }

  Future<void> cancelAll() async {
    try { await _channel.invokeMethod('cancel'); } catch (_) {}
  }
}
