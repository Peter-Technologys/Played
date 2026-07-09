import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

// ── Message models ─────────────────────────────────────────────────────────────────────

enum ChatMessageType { chatMessage, transferAlert, systemEvent }

class ChatMessage {
  final ChatMessageType type;
  final String          sender;
  final String          text;
  final String?         fileName;
  final String?         status;   // 'STARTED', 'COMPLETED', 'FAILED'
  final DateTime        timestamp;

  const ChatMessage({
    required this.type,
    required this.sender,
    required this.text,
    this.fileName,
    this.status,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'CHAT_MESSAGE';
    final type = switch (typeStr) {
      'CHAT_MESSAGE'    => ChatMessageType.chatMessage,
      'TRANSFER_ALERT'  => ChatMessageType.transferAlert,
      _                 => ChatMessageType.systemEvent,
    };
    return ChatMessage(
      type:      type,
      sender:    json['sender']   as String? ?? 'Unknown',
      text:      json['text']     as String? ?? '',
      fileName:  json['fileName'] as String?,
      status:    json['status']   as String?,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type':     switch (type) {
      ChatMessageType.chatMessage   => 'CHAT_MESSAGE',
      ChatMessageType.transferAlert => 'TRANSFER_ALERT',
      ChatMessageType.systemEvent   => 'SYSTEM_EVENT',
    },
    'sender':   sender,
    'text':     text,
    if (fileName != null) 'fileName': fileName,
    if (status   != null) 'status':   status,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  /// Convenience factory for a chat message.
  factory ChatMessage.chat({required String sender, required String text}) =>
      ChatMessage(
        type:      ChatMessageType.chatMessage,
        sender:    sender,
        text:      text,
        timestamp: DateTime.now(),
      );

  /// Convenience factory for a transfer alert.
  factory ChatMessage.transfer({
    required String sender,
    required String fileName,
    required String status,
  }) =>
      ChatMessage(
        type:      ChatMessageType.transferAlert,
        sender:    sender,
        text:      switch (status) {
          'COMPLETED' => '✔ Transfer complete: $fileName',
          'STARTED'   => '🚀 Sending $fileName…',
          'FAILED'    => '❌ Transfer failed: $fileName',
          _           => status,
        },
        fileName:  fileName,
        status:    status,
        timestamp: DateTime.now(),
      );
}

// ── MediaChatService ─────────────────────────────────────────────────────────────────────

/// Passes JSON-serialized ChatMessage objects across a TCP socket stream.
///
/// Architecture:
///   • Uses a broadcast StreamController so multiple UI widgets (chat
///     overlay, notification banner, conversation list) can all listen
///     to the same stream without creating multiple socket connections.
///   • All socket I/O runs on the Dart I/O thread — the UI thread is
///     never blocked, maintaining 60+ FPS during heavy file transfers.
///   • Newline-delimited JSON (‘\n’) is used as the framing protocol
///     because it is trivially parseable and has zero overhead.
class MediaChatService {
  MediaChatService._();
  static final MediaChatService instance = MediaChatService._();

  // broadcast() allows multiple listeners without back-pressure issues.
  final _controller = StreamController<ChatMessage>.broadcast();

  /// Listen to this stream to receive all incoming messages.
  Stream<ChatMessage> get messages => _controller.stream;

  // Active connections
  ServerSocket?        _server;
  final List<Socket>   _clients = [];
  Socket?              _clientSocket; // when acting as a client
  StreamSubscription?  _clientSub;
  final StringBuffer   _readBuf = StringBuffer();

  String? _myName;

  // ── Server mode (receiver device) ───────────────────────────────────────────────────────

  /// Start a TCP chat server on [port] (default 9091 — separate from
  /// the event server on 9090 to avoid port conflicts).
  Future<void> startServer({String myName = 'Device', int port = 9091}) async {
    _myName = myName;
    await stopServer();
    _server = await ServerSocket.bind(
        InternetAddress.anyIPv4, port, shared: true);
    debugPrint('[ChatService] Server listening on port $port');

    _server!.listen(
      (socket) {
        debugPrint('[ChatService] Client connected: ${socket.remoteAddress.address}');
        _clients.add(socket);
        _attachReader(socket);
        socket.done.then((_) {
          _clients.remove(socket);
          debugPrint('[ChatService] Client disconnected.');
        });
      },
      onError: (Object e) => debugPrint('[ChatService] Server error: $e'),
      cancelOnError: false,
    );
  }

  Future<void> stopServer() async {
    for (final c in _clients) { try { c.destroy(); } catch (_) {} }
    _clients.clear();
    await _server?.close();
    _server = null;
  }

  // ── Client mode (sender device) ───────────────────────────────────────────────────────

  Future<void> connectToServer({
    required String host,
    String myName = 'Device',
    int    port   = 9091,
  }) async {
    _myName = myName;
    await disconnectFromServer();
    try {
      _clientSocket = await Socket.connect(
          host, port, timeout: const Duration(seconds: 5));
      debugPrint('[ChatService] Connected to $host:$port');
      _attachReader(_clientSocket!);
    } catch (e) {
      debugPrint('[ChatService] Connect failed: $e');
      rethrow;
    }
  }

  Future<void> disconnectFromServer() async {
    await _clientSub?.cancel();
    _clientSub = null;
    try { _clientSocket?.destroy(); } catch (_) {}
    _clientSocket = null;
    _readBuf.clear();
  }

  // ── Send ───────────────────────────────────────────────────────────────────────────────────

  /// Send a chat message to all connected peers.
  void sendChat(String text) {
    final msg = ChatMessage.chat(sender: _myName ?? 'Me', text: text);
    _broadcast(msg);
    // Echo to local stream so the sender sees their own message.
    _controller.add(msg);
  }

  /// Broadcast a transfer status alert to all connected peers.
  void sendTransferAlert({required String fileName, required String status}) {
    final msg = ChatMessage.transfer(
      sender:   _myName ?? 'Me',
      fileName: fileName,
      status:   status,
    );
    _broadcast(msg);
    _controller.add(msg);
  }

  // ── Private helpers ───────────────────────────────────────────────────────────────

  void _broadcast(ChatMessage msg) {
    final bytes = utf8.encode('${jsonEncode(msg.toJson())}\n');
    final dead  = <Socket>[];
    // Broadcast to server clients
    for (final c in _clients) {
      try { c.add(bytes); } catch (_) { dead.add(c); }
    }
    for (final d in dead) { _clients.remove(d); d.destroy(); }
    // Also send via client socket if connected
    try { _clientSocket?.add(bytes); } catch (_) {}
  }

  void _attachReader(Socket socket) {
    final buf = StringBuffer();
    socket.transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>).listen(
      (chunk) {
        buf.write(chunk);
        final lines = buf.toString().split('\n');
        buf..clear()..write(lines.last);
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final msg  = ChatMessage.fromJson(json);
            // Add to broadcast stream — all UI listeners receive it
            // without blocking the socket read loop.
            _controller.add(msg);
          } catch (e) {
            debugPrint('[ChatService] Parse error: $e  raw=$line');
          }
        }
      },
      onError: (Object e) => debugPrint('[ChatService] Read error: $e'),
      onDone:  ()          => debugPrint('[ChatService] Socket closed.'),
      cancelOnError: false,
    );
  }

  void dispose() {
    stopServer();
    disconnectFromServer();
    _controller.close();
  }
}
