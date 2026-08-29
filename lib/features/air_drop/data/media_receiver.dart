import 'dart:io';
import 'package:flutter/foundation.dart';

/// Progress callback: (bytesDownloaded, totalBytes).
/// totalBytes is -1 if the server did not send Content-Length.
typedef ProgressCallback = void Function(int bytesDownloaded, int totalBytes);

/// MediaReceiver — pure Dart HTTP file downloader.
///
/// Incoming bytes are streamed directly to disk so large videos never need to
/// be buffered in memory. Resume is allowed only when a small sidecar proves
/// that the partial file belongs to the same OTYA transfer endpoint/token.
/// A different transfer using the same advertised filename is saved under a
/// numbered name instead of being appended to unrelated bytes.
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

    final fingerprint = _fingerprint(uri);
    final saveFile = await _destinationFor(savePath, fingerprint);
    await saveFile.parent.create(recursive: true);
    final sidecar = _sidecarFor(saveFile);

    var existingBytes = 0;
    if (await saveFile.exists() &&
        await sidecar.exists() &&
        await sidecar.readAsString() == fingerprint) {
      existingBytes = await saveFile.length();
    } else {
      // This path is either new or belongs to an older/different transfer.
      // _destinationFor normally returns a unique name for the latter case.
      existingBytes = 0;
      await sidecar.writeAsString(fingerprint, flush: true);
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
        // The previous connection may have written the final bytes before the
        // completion signal was received. The matching sidecar means these
        // bytes belong to this exact transfer, so treating them as complete is
        // safe. The sidecar is removed once completion is accepted.
        debugPrint('[MediaReceiver] Existing partial already satisfies transfer.');
        onProgress?.call(existingBytes, existingBytes);
        await _deleteSidecar(sidecar);
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

      await _deleteSidecar(sidecar);
      debugPrint('[MediaReceiver] Saved to ${saveFile.path} ($downloaded bytes)');
      return saveFile;
    } catch (_) {
      await sink?.close();
      // Keep both partial bytes and sidecar for cancellation/network failure.
      // A later retry of the same QR/link can safely request the missing range.
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  String _fingerprint(Uri uri) {
    // The random transfer token makes this identity specific to one serving
    // session. Host/port/path protect against accidental token reuse.
    final token = uri.queryParameters['t'] ?? '';
    return '${uri.host}:${uri.port}${uri.path}|$token';
  }

  File _sidecarFor(File file) => File('${file.path}.otya-transfer');

  Future<File> _destinationFor(String requestedPath, String fingerprint) async {
    final requested = File(requestedPath);
    if (!await requested.exists()) return requested;

    final existingSidecar = _sidecarFor(requested);
    if (await existingSidecar.exists()) {
      try {
        if (await existingSidecar.readAsString() == fingerprint) {
          return requested;
        }
      } catch (_) {}
    }

    final slash = requestedPath.lastIndexOf(Platform.pathSeparator);
    final dir = slash >= 0 ? requestedPath.substring(0, slash + 1) : '';
    final name = slash >= 0 ? requestedPath.substring(slash + 1) : requestedPath;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';

    for (var i = 2; i <= 999; i++) {
      final candidate = File('$dir$base ($i)$ext');
      if (!await candidate.exists()) return candidate;
      final sidecar = _sidecarFor(candidate);
      if (await sidecar.exists()) {
        try {
          if (await sidecar.readAsString() == fingerprint) return candidate;
        } catch (_) {}
      }
    }

    return File('$dir${base}_${DateTime.now().millisecondsSinceEpoch}$ext');
  }

  Future<void> _deleteSidecar(File sidecar) async {
    try {
      if (await sidecar.exists()) await sidecar.delete();
    } catch (_) {}
  }

  void cancel() => _cancelled = true;
}

class _CancelledException implements Exception {
  const _CancelledException();

  @override
  String toString() => 'Download was cancelled.';
}
