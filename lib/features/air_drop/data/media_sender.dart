import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Local-network sender used by OTYA Beam.
///
/// Files are streamed directly from disk over a short-lived HTTP server. Every
/// URL includes a random token and the original filename so the receiving
/// device can preserve the correct extension (including APK files).
class MediaSender {
  static const int port = 8080;
  static const int _chunkBytes = 256 * 1024;

  HttpServer? _server;
  String? _filePath;
  String? _apkPath;
  String? _localIp;
  String? _token;

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
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    _filePath = filePath;
    _localIp = await _getLocalIp();
    if (_localIp == '127.0.0.1') {
      throw const SocketException(
        'No local Wi-Fi or hotspot address found. Connect both devices to the same network.',
      );
    }

    _token = _generateToken();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(
      _handleRequest,
      onError: (Object e) => debugPrint('[MediaSender] Error: $e'),
      cancelOnError: false,
    );

    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'otya-transfer';
    final uri = Uri(
      scheme: 'http',
      host: _localIp,
      port: port,
      path: '/media',
      queryParameters: {'t': _token!, 'name': name},
    );
    debugPrint('[MediaSender] Serving $filePath on $uri');
    return uri.toString();
  }

  Future<String?> startServingApk() async {
    final apk = await _resolveApkPath();
    if (apk == null) return null;
    return startServing(apk);
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
    if (_token == null || requestToken != _token) {
      req.response
        ..statusCode = HttpStatus.forbidden
        ..write('Forbidden: invalid token');
      await req.response.close();
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
          ? (int.tryParse(parts[1]) ?? fileLength - 1)
          : fileLength - 1;
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
      HttpHeaders.contentDispositionHeader,
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
      var remaining = contentLength;
      while (remaining > 0) {
        final toRead = remaining < _chunkBytes ? remaining : _chunkBytes;
        final chunk = await raf.read(toRead);
        if (chunk.isEmpty) break;
        response.add(chunk);
        remaining -= chunk.length;
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      await raf?.close();
      await response.close();
    }
  }

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              _isPrivate172(ip)) {
            return ip;
          }
        }
      }
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) return address.address;
        }
      }
    } catch (e) {
      debugPrint('[MediaSender] IP error: $e');
    }
    return '127.0.0.1';
  }

  bool _isPrivate172(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4 || parts.first != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  Future<String?> _resolveApkPath() async {
    if (_apkPath != null) return _apkPath;
    try {
      final parts = Platform.resolvedExecutable.split('/');
      for (var i = parts.length - 1; i >= 0; i--) {
        final candidate = '${parts.sublist(0, i).join('/')}/base.apk';
        if (await File(candidate).exists()) {
          _apkPath = candidate;
          return _apkPath;
        }
      }
    } catch (e) {
      debugPrint('[MediaSender] APK path error: $e');
    }
    return null;
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
      'apk': 'application/vnd.android.package-archive',
    };
    return map[path.split('.').last.toLowerCase()] ??
        'application/octet-stream';
  }
}
