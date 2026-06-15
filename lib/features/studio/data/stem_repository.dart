import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/stem_cache.dart';
import '../../../core/services/cloudflare_service.dart';

class StemResult {
  final String vocalPath;
  final String instrumentalPath;
  const StemResult({required this.vocalPath, required this.instrumentalPath});
}

/// Handles audio splitting via Cloudflare Workers + R2 + Workflows.
///
/// Flow:
///   1. Check local Hive cache — if stems already split, return instantly.
///   2. Upload audio to Cloudflare Worker → triggers a Cloudflare Workflow.
///   3. Workflow runs Demucs/Spleeter server-side, stores stems in R2.
///   4. Poll for completion, download stems to device, cache in Hive.
///
/// This replaces the old audio-separator.net approach with a durable,
/// resumable Cloudflare Workflow that survives network drops.
class StemRepository {
  Future<StemResult> splitAudio(
    File audioFile, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final mediaId = audioFile.path.hashCode.toString();

    // 1. Return cached stems if available — avoids re-uploading
    final cached = PlayedDatabase.instance.getStemCache(mediaId);
    if (cached != null &&
        await File(cached.vocalPath).exists() &&
        await File(cached.instrumentalPath).exists()) {
      onProgress?.call(1.0, 'Loaded from cache');
      return StemResult(
        vocalPath: cached.vocalPath,
        instrumentalPath: cached.instrumentalPath,
      );
    }

    // 2. Upload to Cloudflare Worker + trigger Workflow
    final r2Result = await CloudflareService.instance.splitStems(
      audioFile,
      onProgress: onProgress,
    );

    // 3. Download stems from R2 to local device storage
    final dir = await getApplicationDocumentsDirectory();
    final stemDir = Directory('${dir.path}/stems/$mediaId');
    await stemDir.create(recursive: true);

    final vocalPath        = '${stemDir.path}/vocals.mp3';
    final instrumentalPath = '${stemDir.path}/instrumental.mp3';

    onProgress?.call(0.92, 'Downloading stems...');

    await Future.wait([
      CloudflareService.instance.downloadFromR2(
        r2Result.vocalUrl, vocalPath),
      CloudflareService.instance.downloadFromR2(
        r2Result.instrumentalUrl, instrumentalPath),
    ]);

    // 4. Persist to Hive so next open is instant (offline)
    await PlayedDatabase.instance.saveStemCache(StemCache(
      sourceMediaId: mediaId,
      sourceTitle: audioFile.path.split('/').last,
      vocalPath: vocalPath,
      instrumentalPath: instrumentalPath,
      cachedAt: DateTime.now(),
      splitEngine: 'cloudflare-demucs',
    ));

    onProgress?.call(1.0, 'Done!');

    return StemResult(
      vocalPath: vocalPath,
      instrumentalPath: instrumentalPath,
    );
  }
}
