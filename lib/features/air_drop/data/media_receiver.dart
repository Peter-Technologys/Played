import 'dart:io';
import 'package:flutter/foundation.dart';

/// Progress callback: (bytesDownloaded, totalBytes).
/// totalBytes is -1 if the server did not send Content-Length.
typedef ProgressCallback = void Function(int bytesDownloaded, int totalBytes);

/// MediaReceiver — pure Dart HTTP file downloader.
///
/// Pipes the incoming response stream directly into an IOSink so the
/// file is written to disk in real-time without buffering the entire
/// response in memory. Critical for large video files.
class MediaReceiver {
  bool _cancelled = false;

  Future<File> download({
    required String url,
    required String savePath,
    ProgressCallback? onProgress,
  }) async {
    _cancelled = false;
    final uri    = Uri.parse(url);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout       = const Duration(minutes: 10);
    final saveFile = File(savePath);
    await saveFile.parent.create(recursive: true);
    if (await saveFile.exists()) await saveFile.delete();
    IOSink? sink;
    try {
      final request  = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException('Server returned ${response.statusCode}', uri: uri);
      }
      final totalBytes = response.contentLength;
      int   downloaded = 0;
      sink = saveFile.openWrite(mode: FileMode.writeOnly);
      await for (final chunk in response) {
        if (_cancelled) { debugPrint('[MediaReceiver] Cancelled.'); break; }
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded, totalBytes);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (_cancelled) {
        if (await saveFile.exists()) await saveFile.delete();
        throw const _CancelledException();
      }
      debugPrint('[MediaReceiver] Saved to $savePath ($downloaded bytes)');
      return saveFile;
    } catch (e) {
      await sink?.close();
      if (e is! _CancelledException && await saveFile.exists()) await saveFile.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void cancel() => _cancelled = true;
}

class _CancelledException implements Exception {
  const _CancelledException();
  @override String toString() => 'Download was cancelled.';
}
