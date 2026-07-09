import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef EventCallback = void Function(String eventType, Map<String, dynamic> data);
typedef VoidCallback  = void Function();

/// Connects to a LocalEventServer and streams newline-delimited JSON events.
class LocalEventClient {
  Socket?             _socket;
  StreamSubscription? _sub;
  final StringBuffer  _buf = StringBuffer();

  bool get isConnected => _socket != null;

  Future<void> connect({
    required String host,
    int port = 9090,
    required EventCallback onEvent,
    VoidCallback? onDisconnected,
  }) async {
    await disconnect();
    _socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 5));
    debugPrint('[EventClient] Connected to $host:$port');
    _sub = _socket!.transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>).listen(
      (chunk) {
        _buf.write(chunk);
        final lines = _buf.toString().split('\n');
        _buf..clear()..write(lines.last);
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            onEvent(json['type'] as String? ?? 'UNKNOWN',
                (json['data'] as Map<String, dynamic>?) ?? {});
          } catch (e) { debugPrint('[EventClient] Parse error: $e'); }
        }
      },
      onError: (Object e) { debugPrint('[EventClient] Error: $e'); disconnect(); onDisconnected?.call(); },
      onDone:  ()          { debugPrint('[EventClient] Done.');    disconnect(); onDisconnected?.call(); },
      cancelOnError: true,
    );
  }

  Future<void> disconnect() async {
    await _sub?.cancel(); _sub = null;
    try { _socket?.destroy(); } catch (_) {}
    _socket = null; _buf.clear();
  }
}
