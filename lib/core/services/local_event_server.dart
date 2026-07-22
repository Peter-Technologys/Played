import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Raw TCP broadcast server for local device-to-device event sync.
/// No WebSocket upgrade needed — dart:io ServerSocket is sufficient
/// for a local LAN use-case and has zero native dependencies.
class LocalEventServer {
  static const int port = 9090;
  ServerSocket?      _server;
  final List<Socket> _clients = [];
  StreamSubscription<Socket>? _sub;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    debugPrint('[EventServer] Listening on port $port');
    _sub = _server!.listen((socket) {
      debugPrint('[EventServer] Client: ${socket.remoteAddress.address}');
      _clients.add(socket);
      socket.done.then((_) { _clients.remove(socket); });
    }, onError: (Object e) {
      debugPrint('[EventServer] Error: $e');
      stop();
    }, cancelOnError: false);
  }

  void broadcastEvent(String eventType, Map<String, dynamic> data) {
    final payload = jsonEncode({'type': eventType, 'data': data,
        'ts': DateTime.now().millisecondsSinceEpoch});
    final bytes = utf8.encode('$payload\n');
    final dead  = <Socket>[];
    for (final c in _clients) {
      try { c.add(bytes); } catch (_) { dead.add(c); }
    }
    for (final d in dead) { _clients.remove(d); d.destroy(); }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    for (final c in _clients) { try { c.destroy(); } catch (_) {} }
    _clients.clear();
    await _server?.close();
    _server = null;
  }
}
