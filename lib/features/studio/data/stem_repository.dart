import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/stem_cache.dart';

class StemResult {
  final String vocalPath;
  final String instrumentalPath;
  const StemResult({required this.vocalPath, required this.instrumentalPath});
}

/// Handles audio splitting via audio-separator.net (Option B — free public API).
/// Caches results permanently in Hive for offline playback.
class StemRepository {
  // Free public Spleeter/Demucs API — no API key required
  static const String _baseUrl = 'https://audio-separator.net/api';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  Future<StemResult> splitAudio(File audioFile) async {
    final mediaId = audioFile.path.hashCode.toString();

    // Return cached stems if available — avoids re-uploading
    final cached = PlayedDatabase.instance.getStemCache(mediaId);
    if (cached != null) {
      return StemResult(
        vocalPath: cached.vocalPath,
        instrumentalPath: cached.instrumentalPath,
      );
    }

    // Upload audio file to audio-separator.net
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.path.split('/').last,
      ),
      'model': 'htdemucs',   // High-quality Demucs model
      'stems': '2',          // 2-stem: vocals + accompaniment
      'output_format': 'mp3',
    });

    final response = await _dio.post(
      '$_baseUrl/separate',
      data: formData,
      options: Options(responseType: ResponseType.json),
    );

    if (response.statusCode != 200) {
      throw Exception('Separator API returned ${response.statusCode}');
    }

    final data = response.data as Map<String, dynamic>;
    final vocalUrl         = data['vocals_url']        as String;
    final instrumentalUrl  = data['accompaniment_url'] as String;

    // Download and cache stems locally for offline playback
    final dir = await getApplicationDocumentsDirectory();
    final stemDir = Directory('${dir.path}/stems/$mediaId');
    await stemDir.create(recursive: true);

    final vocalPath        = '${stemDir.path}/vocals.mp3';
    final instrumentalPath = '${stemDir.path}/instrumental.mp3';

    await Future.wait([
      _dio.download(vocalUrl, vocalPath),
      _dio.download(instrumentalUrl, instrumentalPath),
    ]);

    // Persist to Hive so next open is instant
    final stemCache = StemCache(
      sourceMediaId: mediaId,
      sourceTitle: audioFile.path.split('/').last,
      vocalPath: vocalPath,
      instrumentalPath: instrumentalPath,
      cachedAt: DateTime.now(),
      splitEngine: 'demucs-htdemucs',
    );
    await PlayedDatabase.instance.saveStemCache(stemCache);

    return StemResult(
      vocalPath: vocalPath,
      instrumentalPath: instrumentalPath,
    );
  }
}
