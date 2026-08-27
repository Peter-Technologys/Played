import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// MediaSender — pure Dart HTTP file server for OTYA Beam.
///
/// Beam is deliberately local-network only. No cloud relay or internet upload
/// is used. A one-time random token protects the transfer URL from other LAN
/// devices that did not scan the QR code.
class MediaSender {
  static const int port        = 8080;
  static const int _chunkBytes = 256 * 1024; // 256 KB per chunk

  HttpServer? _server;
  String?     _filePath;
  String?     _localIp;
  String?     _token;

  String? get localIp => _localIp;

  static String _generateToken() {
    final rng = Random.secure();
    return List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<String> startServing(String filePath) async {
    await stop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final file = File(filePath);
    if (!await file.exists()) throw FileSystemException('File not found', filePath);

    final ip = await _getLocalIp();
    _filePath = filePath;
    _localIp = ip;
    _token = _generateToken();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);

    final name = Uri.encodeQueryComponent(
      file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'otya-transfer',
    );
    final url = 'http://$ip:$port/media?t=$_token&name=$name';
    debugPrint('[MediaSender] Beam server ready on local network.');
    _server!.listen(
      _handleRequest,
      onError: (Object e) => debugPrint('[MediaSender] Error: $e'),
      cancelOnError: false,
    );
    return url;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _localIp = null;
    _filePath = null;
    _token = null;
    debugPrint('[MediaSender] Stopped.');
  }

  Future<void> _handleRequest(HttpRequest req) async {
    if (req.uri.path != '/media') {
      req.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
      await req.response.close();
      return;
    }

    final requestToken = req.uri.queryParameters['t'];
    if (_token != null && requestToken != _token) {
      req.response
        ..statusCode = HttpStatus.forbidden
        ..write('Forbidden');
      await req.response.close();
      debugPrint('[MediaSender] Rejected a request with an invalid transfer token.');
      return;
    }

    final filePath = _filePath;
    if (filePath == null) {
      req.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write('No file');
      await req.response.close();
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      req.response
        ..statusCode = HttpStatus.notFound
        ..write('File not found');
      await req.response.close();
      return;
    }

    final fileLength = await file.length();
    final mimeType = _mimeType(filePath);
    final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
    int start = 0;
    int end = fileLength - 1;
    bool isPartial = false;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      isPartial = true;
      final parts = rangeHeader.substring(6).split('-');
      start = int.tryParse(parts[0]) ?? 0;
      end = (parts.length > 1 && parts[1].isNotEmpty)
          ? (int.tryParse(parts[1]) ?? (fileLength - 1))
          : (fileLength - 1);
      end = end.clamp(0, fileLength - 1);
      start = start.clamp(0, end);
    }

    final contentLength = end - start + 1;
    final response = req.response
      ..statusCode = isPartial ? HttpStatus.partialContent : HttpStatus.ok
      ..headers.contentType = ContentType.parse(mimeType)
      ..headers.set(HttpHeaders.contentLengthHeader, contentLength)
      ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'otya-transfer';
    response.headers.set(
      'Content-Disposition',
      'attachment; filename="${fileName.replaceAll('"', '')}"',
    );

    if (isPartial) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$fileLength',
      );
    }

    if (req.method == 'HEAD') {
      await response.close();
      return;
    }

    RandomAccessFile? raf;
    try {
      raf = await file.open();
      await raf.setPosition(start);
      int remaining = contentLength;
      while (remaining > 0) {
        final toRead = remaining < _chunkBytes ? remaining : _chunkBytes;
        final chunk = await raf.read(toRead);
        if (chunk.isEmpty) break;
        response.add(chunk);
        remaining -= chunk.length;
        await Future<void>.delayed(Duration.zero);
      }
    } catch (e) {
      debugPrint('[MediaSender] Stream error: $e');
    } finally {
      await raf?.close();
      await response.close();
    }
  }

  Future<String> _getLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final a = int.tryParse(parts[0]);
          final b = int.tryParse(parts[1]);
          final isPrivate = a == 10 ||
              (a == 192 && b == 168) ||
              (a == 172 && b != null && b >= 16 && b <= 31);
          if (isPrivate) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('[MediaSender] Local network discovery failed: $e');
    }
    throw StateError(
      'Connect both devices to the same Wi-Fi or hotspot before using Beam.',
    );
  }

  String _mimeType(String path) {
    const map = {
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      'ts': 'video/mp2t',
      'mp3': 'audio/mpeg',
      'aac': 'audio/aac',
      'flac': 'audio/flac',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'm4a': 'audio/mp4',
      'opus': 'audio/opus',
    };
    return map[path.split('.').last.toLowerCase()] ?? 'application/octet-stream';
  }
}
