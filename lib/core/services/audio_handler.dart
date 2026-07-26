import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'media_notification_service.dart';

/// Concrete [BaseAudioHandler] that bridges media_kit's [Player] to the
/// audio_service foreground service.
///
/// Lifecycle:
///   1. [AudioService.init] creates this handler once in main().
///   2. [AudioHandlerSingleton.instance.handler] holds the returned reference.
///   3. When [AudioPlayerNotifier] creates its [Player], it calls
///      [AudioHandlerSingleton.instance.attachPlayer].
///   4. On dispose, [AudioPlayerNotifier] calls
///      [AudioHandlerSingleton.instance.detachPlayer].
///
/// The handler keeps the Android foreground service alive so the OS does not
/// kill the process when the app is backgrounded or the screen turns off.
/// It also drives the system MediaSession (lock-screen controls, Bluetooth
/// headset buttons) by updating [mediaItem] and [playbackState].
class OtyaAudioHandler extends BaseAudioHandler with SeekHandler {
  Player? _player;

  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  // ── Player attachment ─────────────────────────────────────────────────

  void attachPlayer(Player player) {
    _cancelSubscriptions();
    _player = player;
    _subscribeToPlayer(player);
    debugPrint('[OtyaAudioHandler] Player attached.');
  }

  void detachPlayer() {
    _cancelSubscriptions();
    _player = null;
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    debugPrint('[OtyaAudioHandler] Player detached.');
  }

  void _subscribeToPlayer(Player player) {
    _playingSub = player.stream.playing.listen(
        (playing) => _updatePlaybackState(playing: playing));
    _bufferingSub = player.stream.buffering.listen(
        (buffering) => _updatePlaybackState(buffering: buffering));
    _positionSub = player.stream.position.listen(
        (position) => _updatePlaybackState(position: position));
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

  // ── Playback state ────────────────────────────────────────────────────

  void _updatePlaybackState({
    bool? playing,
    bool? buffering,
    Duration? position,
  }) {
    final p = _player;
    if (p == null) return;

    final isPlaying   = playing   ?? p.state.playing;
    final isBuffering = buffering ?? p.state.buffering;
    final pos         = position  ?? p.state.position;

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

  // ── Called by MediaNotificationService ───────────────────────────────

  /// Satisfies [BaseAudioHandler.updateMediaItem] override contract.
  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  /// Convenience helper used internally to update the media item from
  /// individual fields (title, artist, artUri, duration).
  void updateMediaItemFromParts({
    required String title,
    required String artist,
    Uri? artUri,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: title,
      title: title,
      artist: artist,
      artUri: artUri,
      duration: duration ?? _player?.state.duration,
    ));
  }

  // ── BaseAudioHandler overrides ────────────────────────────────────────

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
  Future<void> skipToNext() async =>
      MediaNotificationService.instance.onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async =>
      MediaNotificationService.instance.onSkipPrevious?.call();
}

// ── Singleton wrapper ─────────────────────────────────────────────────────

class AudioHandlerSingleton {
  AudioHandlerSingleton._();
  static final AudioHandlerSingleton instance = AudioHandlerSingleton._();

  OtyaAudioHandler? _handler;
  OtyaAudioHandler? get handler => _handler;
  set handler(OtyaAudioHandler? h) {
    _handler = h;
    debugPrint('[AudioHandlerSingleton] Handler set: ${h != null}');
  }

  void attachPlayer(Player player) {
    if (_handler == null) {
      debugPrint('[AudioHandlerSingleton] attachPlayer called before handler is set.');
      return;
    }
    _handler!.attachPlayer(player);
  }

  void detachPlayer() => _handler?.detachPlayer();
}
