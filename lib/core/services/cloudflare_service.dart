import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'cloudflare_config.dart';

/// Result returned after a stem-split job completes.
class StemSplitResult {
  final String vocalUrl;         // R2 public URL
  final String instrumentalUrl;  // R2 public URL
  final String jobId;
  const StemSplitResult({
    required this.vocalUrl,
    required this.instrumentalUrl,
    required this.jobId,
  });
}

/// Result returned after an FFmpeg job completes.
class FfmpegResult {
  final String outputUrl;  // R2 public URL
  final String jobId;
  const FfmpegResult({required this.outputUrl, required this.jobId});
}

/// Enum for FFmpeg operation type.
enum FfmpegOperation { extractAudio, trimForWhatsApp }

/// Central Cloudflare integration service.
///
/// Responsibilities:
///   1. Upload audio/video files to a Cloudflare Worker (which stores to R2).
///   2. Trigger Cloudflare Workflows for long-running jobs (stem split, FFmpeg).
///   3. Poll job status until complete or failed.
///   4. Return R2 public URLs for downloading results.
///
/// All methods are offline-safe — they throw descriptive exceptions on
/// network failure so the UI can show a friendly error.
class CloudflareService {
  CloudflareService._();
  static final CloudflareService instance = CloudflareService._();

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: CloudflareConfig.uploadTimeout,
    headers: {
      // Shared secret so only your app can call the Worker
      'X-App-Secret': CloudflareConfig.workerSecret,
    },
  ));

  // ── Stem Splitting ──────────────────────────────────────────────────

  /// Uploads [audioFile] to the stem-splitter Worker and waits for the
  /// Cloudflare Workflow to complete. Returns R2 URLs for both stems.
  ///
  /// Progress is reported via [onProgress] (0.0 → 1.0).
  Future<StemSplitResult> splitStems(
    File audioFile, {
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.05, 'Uploading track...');

    // 1. Upload file + trigger Workflow
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.path.split('/').last,
      ),
      'model': 'htdemucs',
      'stems': '2',
      'output_format': 'mp3',
    });

    final Response uploadResp;
    try {
      uploadResp = await _dio.post(
        '${CloudflareConfig.stemWorkerUrl}/split',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Upload is 0–40% of total progress
            onProgress?.call(0.05 + (sent / total) * 0.35, 'Uploading...');
          }
        },
      );
    } on DioException catch (e) {
      throw _friendlyError('Upload failed', e);
    }

    final jobId = uploadResp.data['job_id'] as String?;
    if (jobId == null) throw Exception('Worker did not return a job_id');

    onProgress?.call(0.42, 'Splitting stems in the cloud...');

    // 2. Poll Workflow status until done
    final result = await _pollJob(
      jobId: jobId,
      statusUrl: '${CloudflareConfig.stemWorkerUrl}/status/$jobId',
      onProgress: (p) => onProgress?.call(0.42 + p * 0.55, 'Processing...'),
    );

    onProgress?.call(1.0, 'Done!');

    return StemSplitResult(
      vocalUrl:        result['vocal_url']         as String,
      instrumentalUrl: result['instrumental_url']  as String,
      jobId: jobId,
    );
  }

  // ── FFmpeg Operations ───────────────────────────────────────────────

  /// Sends [videoFile] to the FFmpeg Worker for audio extraction or
  /// WhatsApp trimming. Returns the R2 URL of the output file.
  Future<FfmpegResult> runFfmpeg({
    required File inputFile,
    required FfmpegOperation operation,
    double startSec = 0,
    double endSec   = 30,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.05, 'Uploading...');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        inputFile.path,
        filename: inputFile.path.split('/').last,
      ),
      'operation': operation == FfmpegOperation.extractAudio
          ? 'extract_audio'
          : 'trim_whatsapp',
      'start_sec': startSec.toString(),
      'end_sec':   endSec.toString(),
    });

    final Response uploadResp;
    try {
      uploadResp = await _dio.post(
        '${CloudflareConfig.ffmpegWorkerUrl}/process',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(0.05 + (sent / total) * 0.4, 'Uploading...');
        },
      );
    } on DioException catch (e) {
      throw _friendlyError('Upload failed', e);
    }

    final jobId = uploadResp.data['job_id'] as String?;
    if (jobId == null) throw Exception('Worker did not return a job_id');

    onProgress?.call(0.47, 'Processing with FFmpeg...');

    final result = await _pollJob(
      jobId: jobId,
      statusUrl: '${CloudflareConfig.ffmpegWorkerUrl}/status/$jobId',
      onProgress: (p) => onProgress?.call(0.47 + p * 0.5, 'Processing...'),
    );

    onProgress?.call(1.0, 'Done!');

    return FfmpegResult(
      outputUrl: result['output_url'] as String,
      jobId: jobId,
    );
  }

  // ── R2 Download ─────────────────────────────────────────────────────

  /// Downloads a file from an R2 public URL to [localPath].
  Future<void> downloadFromR2(
    String r2Url,
    String localPath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _dio.download(
        r2Url,
        localPath,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
    } on DioException catch (e) {
      throw _friendlyError('Download failed', e);
    }
  }

  // ── Polling ─────────────────────────────────────────────────────────

  /// Polls [statusUrl] every [CloudflareConfig.pollInterval] until the
  /// Workflow reports `status == 'complete'` or `status == 'error'`.
  /// Times out after [CloudflareConfig.jobMaxWait].
  Future<Map<String, dynamic>> _pollJob({
    required String jobId,
    required String statusUrl,
    void Function(double progress)? onProgress,
  }) async {
    final deadline = DateTime.now().add(CloudflareConfig.jobMaxWait);
    int attempt = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(CloudflareConfig.pollInterval);
      attempt++;

      try {
        final resp = await _dio.get(statusUrl);
        final data = resp.data as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'pending';

        // Fake smooth progress while waiting (never reaches 1.0 here)
        onProgress?.call((attempt * 0.08).clamp(0.0, 0.95));

        if (status == 'complete') return data;
        if (status == 'error') {
          throw Exception(data['error'] ?? 'Job failed on server');
        }
        // status == 'pending' | 'processing' — keep polling
      } on DioException catch (e) {
        debugPrint('[Cloudflare] Poll attempt $attempt failed: $e');
        // Transient network error — keep trying until deadline
      }
    }

    throw Exception(
        'Job $jobId timed out after ${CloudflareConfig.jobMaxWait.inMinutes} minutes');
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  String _friendlyError(String prefix, DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '$prefix: Connection timed out. Check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '$prefix: No internet connection.';
    }
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return '$prefix: Unauthorised — check CF_WORKER_SECRET.';
    }
    return '$prefix: ${e.message}';
  }
}
