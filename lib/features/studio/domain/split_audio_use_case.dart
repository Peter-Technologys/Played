import 'dart:io';
import '../../../core/database/played_database.dart';
import '../../../core/models/stem_cache.dart';

class StemResult {
  final String vocalPath;
  final String instrumentalPath;
  const StemResult(
      {required this.vocalPath, required this.instrumentalPath});
}

/// Domain use case: splits an audio file into vocal + instrumental stems.
/// Checks local cache first; falls back to remote API.
class SplitAudioUseCase {
  final Future<StemResult> Function(File file) _splitFn;

  SplitAudioUseCase(this._splitFn);

  Future<StemResult> execute(File audioFile) async {
    final mediaId = audioFile.path.hashCode.toString();

    // 1. Return cached stems if available
    final cached = PlayedDatabase.instance.getStemCache(mediaId);
    if (cached != null) {
      return StemResult(
        vocalPath: cached.vocalPath,
        instrumentalPath: cached.instrumentalPath,
      );
    }

    // 2. Call the split function (API or local)
    final result = await _splitFn(audioFile);

    // 3. Persist to Hive for permanent offline access
    await PlayedDatabase.instance.saveStemCache(
      StemCache(
        sourceMediaId: mediaId,
        sourceTitle: audioFile.path.split('/').last,
        vocalPath: result.vocalPath,
        instrumentalPath: result.instrumentalPath,
        cachedAt: DateTime.now(),
        splitEngine: 'spleeter',
      ),
    );

    return result;
  }
}
