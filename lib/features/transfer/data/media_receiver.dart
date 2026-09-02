import 'dart:io';

import 'package:flutter/foundation.dart';

/// Progress callback: (bytesDownloaded, totalBytes).
/// totalBytes is -1 if the server did not send Content-Length.
typedef ProgressCallback = void Function(int bytesDownloaded, int totalBytes);

/// MediaReceiver — pure Dart HTTP file downloader for Otya Transfer.
///
/// Incoming bytes are streamed directly to disk so large videos never need to
/// be buffered in memory. Resume is allowed only when a small sidecar proves
/// that the partial file belongs to the same Otya transfer endpoint/token.
/// A different transfer using the same advertised filename is saved under a
/// numbered name instead of being appended to unrelated bytes.
class MediaReceiver {
  static const int _maxTransferBytes = 16 * 1024 * 1024 * 1024;
  static const Set<String> _supportedExtensions = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'ts',
    'mp3',
    'aac',
    'flac',
    'wav',
    'ogg',
    'm4a',
    'opus',
  };

  bool _cancelled = false;

  Future<File> download({
    required String url,
    required String savePath,
    ProgressCallback? onProgress,
  }) async {
    _cancelled = false;
    final uri = Uri.parse(url);
    if (!_isAllowedTransferUri(uri)) {
      throw const FormatException(
        'Otya Transfer only accepts authenticated private local-network links.',
      );
    }
    if (!_supportedExtensions.contains(_extension(savePath))) {
      throw const FormatException('Otya Transfer only receives supported media files.');
    }

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
      if (existingBytes > _maxTransferBytes) {
        throw const FileSystemException('Partial transfer exceeds Otya safety limit.');
      }
    } else {
      existingBytes = 0;
      await sidecar.writeAsString(fingerprint, flush: true);
    }

    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      if (existingBytes > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
      }

      final response = await request.close();
      if (_isRedirect(response.statusCode)) {
        await response.drain<void>();
        throw const HttpException('Otya Transfer does not follow redirects.');
      }
      if (response.headers.value('X-Otya-Transfer') != '1') {
        await response.drain<void>();
        throw const HttpException('The nearby endpoint is not an Otya Transfer sender.');
      }

      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
          existingBytes > 0) {
        final remoteLength = _lengthFromUnsatisfiedRange(response);
        await response.drain<void>();
        if (remoteLength != null &&
            remoteLength <= _maxTransferBytes &&
            existingBytes == remoteLength) {
          debugPrint(
            '[MediaReceiver] Existing partial exactly matches remote transfer.',
          );
          onProgress?.call(existingBytes, existingBytes);
          await _deleteSidecar(sidecar);
          return saveFile;
        }

        debugPrint(
          '[MediaReceiver] Resume offset is invalid; restarting transfer.',
        );
        if (await saveFile.exists()) await saveFile.delete();
        await sidecar.writeAsString(fingerprint, flush: true);
        return download(
          url: url,
          savePath: saveFile.path,
          onProgress: onProgress,
        );
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException('Server returned ${response.statusCode}', uri: uri);
      }

      final contentType = response.headers.contentType?.mimeType.toLowerCase() ?? '';
      if (!contentType.startsWith('audio/') && !contentType.startsWith('video/')) {
        await response.drain<void>();
        throw const HttpException('Otya Transfer rejected a non-media response.');
      }

      final isResume = response.statusCode == HttpStatus.partialContent &&
          existingBytes > 0;
      if (!isResume) existingBytes = 0;

      final responseBytes = response.contentLength;
      if (responseBytes < 0) {
        await response.drain<void>();
        throw const HttpException('Otya Transfer requires a known file size.');
      }
      final totalBytes = existingBytes + responseBytes;
      if (totalBytes <= 0 || totalBytes > _maxTransferBytes) {
        await response.drain<void>();
        throw const HttpException('Transfer size is outside Otya safety limits.');
      }
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
        downloaded += chunk.length;
        if (downloaded > _maxTransferBytes || downloaded > totalBytes) {
          throw const HttpException('Otya Transfer exceeded the declared safe size.');
        }
        sink.add(chunk);
        onProgress?.call(downloaded, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (_cancelled) throw const TransferCancelledException();

      if (downloaded != totalBytes) {
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
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  int? _lengthFromUnsatisfiedRange(HttpClientResponse response) {
    final header = response.headers.value(HttpHeaders.contentRangeHeader);
    if (header == null) return null;
    final match = RegExp(r'^bytes \*/(\d+)$').firstMatch(header.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  bool _isAllowedTransferUri(Uri uri) {
    if (uri.scheme != 'http' ||
        uri.path != '/media' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.port <= 0 ||
        uri.port > 65535) {
      return false;
    }
    final token = uri.queryParameters['t'] ?? '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) return false;

    final parts = uri.host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList(growable: false);
    if (octets.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }
    final a = octets[0]!;
    final b = octets[1]!;
    return a == 10 ||
        a == 127 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  String _fingerprint(Uri uri) {
    final token = uri.queryParameters['t'] ?? '';
    return '${uri.host}:${uri.port}${uri.path}|$token';
  }

  String _extension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
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

class TransferCancelledException implements Exception {
  const TransferCancelledException();

  @override
  String toString() => 'Transfer was cancelled.';
}
