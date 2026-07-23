import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// MediaSender — pure Dart HTTP file server.
///
/// Why no native plugin:
///   nearby_connections requires CMake native compilation which causes
///   CI runner timeouts. This uses only dart:io HttpServer — zero native
///   dependencies, compiles in milliseconds.
///
/// Features:
///   • Range-request support (HTTP 206 Partial Content) so the receiver
///     can seek through the video while it is still downloading.
///   • Chunked streaming — the file is never fully loaded into memory;
///     piped in 256 KB chunks directly from disk to the socket.
///   • APK self-share — exposes the app’s own installed APK so nearby
///     friends can install OTYA Player without internet.
class MediaSender {
  static const int port        = 8080;
  static const int _chunkBytes = 256 * 1024; // 256 KB per chunk

  HttpServer? _server;
  String?     _filePath;
  String?     _apkPath;
  String?     _localIp;

  String? get localIp => _localIp;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<String> startServing(String filePath) async {
    await stop();
    // Give the OS a brief window to release the port after stop().
    // Without this delay, rapid start→stop→start cycles can hit EADDRINUSE
    // because the kernel TIME_WAIT state has not cleared yet.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final file = File(filePath);
    if (!await file.exists()) throw FileSystemException('File not found', filePath);
    _filePath = filePath;
    _localIp  = await _getLocalIp();
    _server   = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    debugPrint('[MediaSender] Serving $filePath on http://$_localIp:$port/media');
    _server!.listen(_handleRequest,
        onError: (Object e) => debugPrint('[MediaSender] Error: $e'),
        cancelOnError: false);
    return 'http://$_localIp:$port/media';
  }

  Future<String?> startServingApk() async {
    final apk = await _resolveApkPath();
    if (apk == null) return null;
    return startServing(apk);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null; _localIp = null; _filePath = null;
    debugPrint('[MediaSender] Stopped.');
  }

  // ── Request handler ───────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest req) async {
    final path    = req.uri.path;
    final isMedia = path == '/media';
    final isApk   = path == '/apk';
    if (!isMedia && !isApk) {
      req.response..statusCode = HttpStatus.notFound..write('Not found')..close();
      return;
    }
    final filePath = isApk ? (await _resolveApkPath()) : _filePath;
    if (filePath == null) {
      req.response..statusCode = HttpStatus.serviceUnavailable..write('No file')..close();
      return;
    }
    final file = File(filePath);
    if (!await file.exists()) {
      req.response..statusCode = HttpStatus.notFound..write('File not found')..close();
      return;
    }
    final fileLength = await file.length();
    final mimeType   = _mimeType(filePath);

    // Range request handling — allows the receiver to seek before download completes
    final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
    int start = 0, end = fileLength - 1;
    bool isPartial = false;
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      isPartial = true;
      final parts = rangeHeader.substring(6).split('-');
      start = int.tryParse(parts[0]) ?? 0;
      end   = (parts.length > 1 && parts[1].isNotEmpty)
          ? (int.tryParse(parts[1]) ?? (fileLength - 1))
          : (fileLength - 1);
      end   = end.clamp(0, fileLength - 1);
      start = start.clamp(0, end);
    }
    final contentLength = end - start + 1;
    final response = req.response
      ..statusCode = isPartial ? HttpStatus.partialContent : HttpStatus.ok
      ..headers.contentType = ContentType.parse(mimeType)
      ..headers.set(HttpHeaders.contentLengthHeader, contentLength)
      ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    if (isPartial) {
      response.headers.set(
          HttpHeaders.contentRangeHeader, 'bytes $start-$end/$fileLength');
    }
    if (req.method == 'HEAD') { await response.close(); return; }

    // Stream in 256 KB chunks — never loads the whole file into memory
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      await raf.setPosition(start);
      int remaining = contentLength;
      while (remaining > 0) {
        final toRead = remaining < _chunkBytes ? remaining : _chunkBytes;
        final chunk  = await raf.read(toRead);
        if (chunk.isEmpty) break;
        response.add(chunk);
        remaining -= chunk.length;
        await Future<void>.delayed(Duration.zero); // yield to event loop
      }
    } catch (e) {
      debugPrint('[MediaSender] Stream error: $e');
    } finally {
      await raf?.close();
      await response.close();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _getLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final iface in ifaces)
        for (final addr in iface.addresses)
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.')) return addr.address;
      for (final iface in ifaces)
        for (final addr in iface.addresses)
          if (!addr.isLoopback) return addr.address;
    } catch (e) { debugPrint('[MediaSender] IP error: $e'); }
    return '127.0.0.1';
  }

  Future<String?> _resolveApkPath() async {
    if (_apkPath != null) return _apkPath;
    try {
      final parts = Platform.resolvedExecutable.split('/');
      for (var i = parts.length - 1; i >= 0; i--) {
        final candidate = '${parts.sublist(0, i).join('/')}/base.apk';
        if (await File(candidate).exists()) { _apkPath = candidate; return _apkPath; }
      }
    } catch (e) { debugPrint('[MediaSender] APK path error: $e'); }
    return null;
  }

  String _mimeType(String path) {
    const map = {
      'mp4': 'video/mp4', 'mkv': 'video/x-matroska', 'avi': 'video/x-msvideo',
      'mov': 'video/quicktime', 'webm': 'video/webm', 'ts': 'video/mp2t',
      'mp3': 'audio/mpeg', 'aac': 'audio/aac', 'flac': 'audio/flac',
      'wav': 'audio/wav', 'ogg': 'audio/ogg', 'm4a': 'audio/mp4',
      'opus': 'audio/opus', 'apk': 'application/vnd.android.package-archive',
    };
    return map[path.split('.').last.toLowerCase()] ?? 'application/octet-stream';
  }
}
