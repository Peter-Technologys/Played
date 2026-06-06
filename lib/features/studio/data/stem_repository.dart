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

/// Handles audio splitting via remote Spleeter/Demucs API.
/// Caches results permanently in Hive for offline playback.
class StemRepository {
  // Replace with your deployed Spleeter/Demucs endpoint
  static const String _baseUrl = 'https://your-spleeter-api.com';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  Future<StemResult> splitAudio(File audioFile) async {
    final mediaId = audioFile.path.hashCode.toString();

    // Return cached stems if available
    final cached = PlayedDatabase.instance.getStemCache(mediaId);
    if (cached != null) {
      return StemResult(
        vocalPath: cached.vocalPath,
        instrumentalPath: cached.instrumentalPath,
      );
    }

    // Upload to Spleeter API
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.path.split('/').last,
      ),
      'stems': '2', // 2-stem split: vocals + accompaniment
    });

    final response = await _dio.post(
      '$_baseUrl/split',
      data: formData,
      options: Options(responseType: ResponseType.json),
    );

    if (response.statusCode != 200) {
      throw Exception('Split API returned ${response.statusCode}');
    }

    final data = response.data as Map<String, dynamic>;
    final vocalUrl = data['vocals_url'] as String;
    final instrumentalUrl = data['accompaniment_url'] as String;

    // Download and cache stems locally
    final dir = await getApplicationDocumentsDirectory();
    final stemDir = Directory('${dir.path}/stems/$mediaId');
    await stemDir.create(recursive: true);

    final vocalPath = '${stemDir.path}/vocals.mp3';
    final instrumentalPath = '${stemDir.path}/instrumental.mp3';

    await Future.wait([
      _dio.download(vocalUrl, vocalPath),
      _dio.download(instrumentalUrl, instrumentalPath),
    ]);

    // Persist to Hive
    final stemCache = StemCache(
      sourceMediaId: mediaId,
      sourceTitle: audioFile.path.split('/').last,
      vocalPath: vocalPath,
      instrumentalPath: instrumentalPath,
      cachedAt: DateTime.now(),
      splitEngine: 'spleeter',
    );
    await PlayedDatabase.instance.saveStemCache(stemCache);

    return StemResult(
      vocalPath: vocalPath,
      instrumentalPath: instrumentalPath,
    );
  }
}
