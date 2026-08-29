import 'dart:io';
import 'package:flutter/foundation.dart';

/// Progress callback: (bytesDownloaded, totalBytes).
/// totalBytes is -1 if the server did not send Content-Length.
typedef ProgressCallback = void Function(int bytesDownloaded, int totalBytes);

/// MediaReceiver — pure Dart HTTP file downloader.
///
/// Incoming bytes are streamed directly to disk so large videos never need to
/// be buffered in memory. When a partial file already exists, OTYA asks the
/// sender for the remaining range and appends it. A cancelled/interrupted
/// transfer therefore keeps its partial bytes and can continue later.
class MediaReceiver {
  bool _cancelled = false;

  Future<File> download({
    required String url,
    required String savePath,
    ProgressCallback? onProgress,
  }) async {
    _cancelled = false;
    final uri = Uri.parse(url);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(minutes: 10);
    final saveFile = File(savePath);
    await saveFile.parent.create(recursive: true);

    var existingBytes = 0;
    if (await saveFile.exists()) {
      existingBytes = await saveFile.length();
    }

    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      if (existingBytes > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
      }

      final response = await request.close();
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
          existingBytes > 0) {
        // The local file can already be complete if the previous connection
        // dropped after the final bytes were written but before completion was
        // reported to the UI.
        debugPrint('[MediaReceiver] Existing file already satisfies transfer.');
        onProgress?.call(existingBytes, existingBytes);
        return saveFile;
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException('Server returned ${response.statusCode}', uri: uri);
      }

      final isResume = response.statusCode == HttpStatus.partialContent &&
          existingBytes > 0;
      if (!isResume) {
        existingBytes = 0;
      }

      final responseBytes = response.contentLength;
      final totalBytes = responseBytes >= 0
          ? existingBytes + responseBytes
          : -1;
      var downloaded = existingBytes;

      sink = saveFile.openWrite(
        mode: isResume ? FileMode.append : FileMode.writeOnly,
      );
      onProgress?.call(downloaded, totalBytes);

      await for (final chunk in response) {
        if (_cancelled) {
          debugPrint('[MediaReceiver] Cancelled; partial file kept for resume.');
          break;
        }
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (_cancelled) {
        throw const _CancelledException();
      }

      if (totalBytes >= 0 && downloaded != totalBytes) {
        throw HttpException(
          'Transfer ended early ($downloaded of $totalBytes bytes)',
          uri: uri,
        );
      }

      debugPrint('[MediaReceiver] Saved to $savePath ($downloaded bytes)');
      return saveFile;
    } catch (e) {
      await sink?.close();
      // Keep partial bytes for cancellation and ordinary network interruption.
      // A later retry will request only the missing range from an OTYA sender.
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void cancel() => _cancelled = true;
}

class _CancelledException implements Exception {
  const _CancelledException();

  @override
  String toString() => 'Download was cancelled.';
}
