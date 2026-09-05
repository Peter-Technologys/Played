import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/models/media_item.dart';
import '../../../core/services/otya_identity_service.dart';
import '../data/nearby_together_channel.dart';
import '../domain/together_message.dart';
import '../domain/together_session.dart';
import 'media_kit_together_adapter.dart';
import 'nearby_together_session.dart';
import 'together_session_controller.dart';

/// Process-local owner for an active Nearby Together host room.
///
/// The runtime deliberately outlives the invite sheet so closing the sheet does
/// not stop the watch party. It owns only Together resources and attaches to the
/// Player that already exists; normal local playback never depends on it.
class NearbyTogetherRuntime extends ChangeNotifier {
  NearbyTogetherRuntime._();

  static final instance = NearbyTogetherRuntime._();

  final TogetherSessionController _room = TogetherSessionController();

  NearbyTogetherHostSession? _host;
  MediaKitTogetherAdapter? _adapter;
  NearbyTogetherInvite? _invite;
  StreamSubscription<NearbyTogetherMessage>? _messageSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  Timer? _heartbeat;

  String? _localParticipantId;
  String? _lastError;
  bool _starting = false;

  TogetherSessionState get state => _room.state;
  NearbyTogetherInvite? get invite => _invite;
  String? get localParticipantId => _localParticipantId;
  String? get lastError => _lastError;
  bool get starting => _starting;
  bool get active => state.hasActiveSession;

  Future<NearbyTogetherInvite> startHost({
    required MediaItem mediaItem,
    required Player player,
    String? displayName,
  }) async {
    if (_starting) {
      throw StateError('Together is already starting.');
    }
    _starting = true;
    _lastError = null;
    notifyListeners();

    try {
      await stop(notify: false);

      final username = await OtyaIdentityService.instance.cachedUsername();
      final host = NearbyTogetherHostSession();
      final resolvedName = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : username?.isNotEmpty == true
              ? '@$username'
              : 'OTYA user';

      final invite = await host.start(
        filePath: mediaItem.filePath,
        displayName: resolvedName,
        username: username,
        duration: mediaItem.duration,
      );
      final media = host.mediaIdentity;
      if (media == null) {
        await host.dispose();
        throw StateError('OTYA could not identify this video for Together.');
      }

      _host = host;
      _invite = invite;
      _adapter = MediaKitTogetherAdapter(player: player);
      _localParticipantId = _ephemeralId('host');

      final now = DateTime.now().toUtc();
      _room.start(
        TogetherSession(
          id: _ephemeralId('room'),
          hostParticipantId: _localParticipantId!,
          activeMediaFingerprint: media.fingerprint,
          phase: TogetherSessionPhase.connecting,
          participants: [
            TogetherParticipant(
              id: _localParticipantId!,
              displayName: resolvedName,
              username: username,
              role: TogetherParticipantRole.host,
              isConnected: true,
              joinedAt: now,
            ),
          ],
          createdAt: now,
        ),
      );

      _messageSub = host.channel.messages.listen(_handleGuestMessage);
      _connectionSub = host.channel.connected.listen(_handleConnection);
      _playingSub = player.stream.playing.listen((_) => unawaited(_sendHostState()));
      _completedSub = player.stream.completed.listen((completed) {
        if (!completed || !state.hasActiveSession) return;
        try {
          _room.playbackEnded(DateTime.now().toUtc());
          notifyListeners();
          unawaited(_sendHostState());
        } catch (_) {}
      });
      _heartbeat = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(_sendHostState()),
      );

      notifyListeners();
      return invite;
    } catch (error) {
      _lastError = _friendlyError(error);
      rethrow;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> sendChat(String rawText) async {
    final text = rawText.trim();
    final session = state.session;
    final sender = _localParticipantId;
    final host = _host;
    if (session == null || sender == null || host == null || text.isEmpty) return;
    if (text.length > TogetherMessage.maxTextLength) {
      throw ArgumentError('Together messages are limited to ${TogetherMessage.maxTextLength} characters.');
    }

    final now = DateTime.now().toUtc();
    _room.receiveMessage(
      TogetherMessage(
        id: _ephemeralId('msg'),
        sessionId: session.id,
        senderParticipantId: sender,
        text: text,
        kind: TogetherMessageKind.text,
        createdAt: now,
      ),
      conversationVisible: true,
    );
    notifyListeners();
    await host.channel.send('chat', {'text': text});
  }

  Future<void> sendMoment(Duration position, {String text = 'Look at this moment'}) async {
    final session = state.session;
    final sender = _localParticipantId;
    final host = _host;
    if (session == null || sender == null || host == null) return;

    final now = DateTime.now().toUtc();
    final cleanText = text.trim().isEmpty ? 'Look at this moment' : text.trim();
    _room.receiveMessage(
      TogetherMessage(
        id: _ephemeralId('moment'),
        sessionId: session.id,
        senderParticipantId: sender,
        text: cleanText,
        kind: TogetherMessageKind.moment,
        mediaPosition: position,
        createdAt: now,
      ),
      conversationVisible: true,
    );
    notifyListeners();
    await host.channel.send('moment', {
      'text': cleanText,
      'position_ms': position.inMilliseconds,
    });
  }

  void markConversationRead() {
    _room.markConversationRead();
    notifyListeners();
  }

  Future<void> stop({bool notify = true}) async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _messageSub?.cancel();
    await _connectionSub?.cancel();
    await _playingSub?.cancel();
    await _completedSub?.cancel();
    _messageSub = null;
    _connectionSub = null;
    _playingSub = null;
    _completedSub = null;

    final host = _host;
    _host = null;
    _adapter = null;
    _invite = null;
    _localParticipantId = null;
    if (host != null) {
      await host.dispose();
    }

    if (_room.state.session != null) {
      _room.close(DateTime.now().toUtc());
      _room.clearClosedRoom();
    }
    if (notify) notifyListeners();
  }

  void _handleConnection(bool connected) {
    final session = state.session;
    if (session == null || !session.isActive) return;
    final now = DateTime.now().toUtc();
    const guestId = 'nearby-guest';
    final existing = session.participants.where((item) => item.id == guestId).firstOrNull;

    try {
      if (connected) {
        _room.addParticipant(
          existing?.copyWith(isConnected: true) ??
              TogetherParticipant(
                id: guestId,
                displayName: 'Nearby guest',
                role: TogetherParticipantRole.guest,
                isConnected: true,
                joinedAt: now,
              ),
          now,
        );
        _room.connected(TogetherConnectionPath.nearby, now);
        unawaited(_sendHostState());
      } else {
        if (existing != null) {
          _room.addParticipant(existing.copyWith(isConnected: false), now);
        }
        _room.reconnecting(now);
      }
      notifyListeners();
    } catch (_) {}
  }

  void _handleGuestMessage(NearbyTogetherMessage message) {
    final session = state.session;
    if (session == null || !session.isActive) return;
    const guestId = 'nearby-guest';

    switch (message.type) {
      case 'ready':
        final name = _text(message.payload['display_name']) ?? 'Nearby guest';
        final username = _text(message.payload['username'])
            ?.replaceFirst(RegExp(r'^@+'), '')
            .toLowerCase();
        try {
          _room.addParticipant(
            TogetherParticipant(
              id: guestId,
              displayName: name,
              username: username,
              role: TogetherParticipantRole.guest,
              isConnected: true,
              joinedAt: message.sentAt,
            ),
            message.sentAt,
          );
          _room.connected(TogetherConnectionPath.nearby, message.sentAt);
          notifyListeners();
        } catch (_) {}
        break;
      case 'chat':
        final text = _text(message.payload['text']);
        if (text == null || text.length > TogetherMessage.maxTextLength) return;
        _room.receiveMessage(
          TogetherMessage(
            id: message.id,
            sessionId: session.id,
            senderParticipantId: guestId,
            text: text,
            kind: TogetherMessageKind.text,
            createdAt: message.sentAt,
          ),
          conversationVisible: false,
        );
        notifyListeners();
        break;
      case 'moment':
        final text = _text(message.payload['text']) ?? 'Look at this moment';
        final positionMs = message.payload['position_ms'];
        if (positionMs is! int || positionMs < 0) return;
        _room.receiveMessage(
          TogetherMessage(
            id: message.id,
            sessionId: session.id,
            senderParticipantId: guestId,
            text: text,
            kind: TogetherMessageKind.moment,
            mediaPosition: Duration(milliseconds: positionMs),
            createdAt: message.sentAt,
          ),
          conversationVisible: false,
        );
        notifyListeners();
        break;
      case 'ping':
        final host = _host;
        final adapter = _adapter;
        if (host != null && adapter != null) {
          unawaited(host.channel.send('pong', {
            'guest_send_us': message.payload['guest_send_us'],
            'host_reply_us': adapter.monotonicClock.elapsedMicroseconds,
          }).catchError((_) {}));
        }
        break;
      case 'bye':
        _handleConnection(false);
        break;
    }
  }

  Future<void> _sendHostState() async {
    final host = _host;
    final adapter = _adapter;
    final session = state.session;
    if (host == null ||
        adapter == null ||
        session == null ||
        !session.isActive ||
        !host.channel.hasGuest ||
        adapter.applyingRemote) {
      return;
    }

    try {
      await host.channel.send(
        'state',
        adapter.captureHostState(mediaRevision: session.mediaRevision).toJson(),
      );
    } catch (_) {
      // Connection changes are reflected by the channel stream. A heartbeat
      // failure must never bubble into or interrupt local playback.
    }
  }

  static String _ephemeralId(String prefix) {
    final rng = Random.secure();
    return '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
        '${rng.nextInt(0x7fffffff).toRadixString(36)}';
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  static String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('Wi-Fi') || message.contains('hotspot')) {
      return 'Connect both phones to the same Wi-Fi or hotspot, then try again.';
    }
    if (message.contains('not found') || message.contains('empty')) {
      return 'That video is no longer available on this device.';
    }
    return 'OTYA could not start Together. Check the local connection and try again.';
  }
}
