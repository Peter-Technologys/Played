import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'media_notification_service.dart';

/// Bridges media_kit's [Player] to Android's MediaSession/foreground service.
class OtyaAudioHandler extends BaseAudioHandler with SeekHandler {
  Player? _player;
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  void attachPlayer(Player player) {
    debugPrint('[OtyaAudioHandler] Attaching player');
    _cancelSubscriptions();
    _player = player;
    _subscribeToPlayer(player);
    debugPrint('[OtyaAudioHandler] Player attached.');
  }

  /// Detaches the player from this handler.
  /// [disposePlayer] controls whether the underlying [Player] is also
  /// disposed. Pass true only when playback is intentionally terminated.
  void detachPlayer({bool disposePlayer = false}) {
    debugPrint('[OtyaAudioHandler] Detaching player');
    _cancelSubscriptions();
    final player = _player;
    _player = null;
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    if (disposePlayer && player != null) {
      try {
        player.dispose();
      } catch (e) {
        debugPrint('[OtyaAudioHandler] Player dispose error: $e');
      }
    }
  }

  void _subscribeToPlayer(Player player) {
    _playingSub = player.stream.playing.listen(
      (playing) => _updatePlaybackState(playing: playing),
    );
    _bufferingSub = player.stream.buffering.listen(
      (buffering) => _updatePlaybackState(buffering: buffering),
    );
    _positionSub = player.stream.position.listen(
      (position) => _updatePlaybackState(position: position),
    );
    _durationSub = player.stream.duration.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != Duration.zero) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  void _cancelSubscriptions() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub = _bufferingSub = _positionSub = _durationSub = null;
  }

  void _updatePlaybackState({
    bool? playing,
    bool? buffering,
    Duration? position,
  }) {
    final p = _player;
    if (p == null) return;
    final isPlaying = playing ?? p.state.playing;
    final isBuffering = buffering ?? p.state.buffering;
    final pos = position ?? p.state.position;
    final processingState = (isBuffering && p.state.duration == Duration.zero)
        ? AudioProcessingState.loading
        : isBuffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: isPlaying,
      updatePosition: pos,
      bufferedPosition: p.state.buffer,
      speed: p.state.rate,
    ));
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  void updateMediaItemFromParts({
    required String id,
    required String title,
    required String artist,
    Uri? artUri,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri,
      duration: duration ?? _player?.state.duration,
    ));
  }

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> stop() async {
    await _player?.pause();
    detachPlayer();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> skipToNext() async {
    MediaNotificationService.instance.onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    MediaNotificationService.instance.onSkipPrevious?.call();
  }

  @override
  Future<void> onTaskRemoved() async {
    // Do not tear down playback when the user swipes OTYA out of Recents.
    // Android's foreground media service owns the active session and should
    // remain available from the lock screen, notification shade and Bluetooth.
    // Playback is terminated only by an explicit stop/dismiss action.
    debugPrint('[OtyaAudioHandler] App task removed; keeping media session alive.');
  }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
    await super.onNotificationDeleted();
  }
}

/// Holds the audio handler and safely bridges the startup race where a media
/// player is created before AudioService.init() has completed.
class AudioHandlerSingleton {
  AudioHandlerSingleton._();
  static final AudioHandlerSingleton instance = AudioHandlerSingleton._();

  OtyaAudioHandler? _handler;
  Player? _pendingPlayer;

  OtyaAudioHandler? get handler => _handler;

  set handler(OtyaAudioHandler? h) {
    _handler = h;
    final pending = _pendingPlayer;
    if (h != null && pending != null) {
      _pendingPlayer = null;
      h.attachPlayer(pending);
    }
    debugPrint('[AudioHandlerSingleton] Handler set: ${h != null}');
  }

  void attachPlayer(Player player) {
    final h = _handler;
    if (h == null) {
      _pendingPlayer = player;
      debugPrint('[AudioHandlerSingleton] Queued player until audio handler is ready.');
      return;
    }
    h.attachPlayer(player);
  }

  void detachPlayer({bool disposePlayer = false}) {
    _pendingPlayer = null;
    _handler?.detachPlayer(disposePlayer: disposePlayer);
  }
}
