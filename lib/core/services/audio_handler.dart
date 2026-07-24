import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/media_item.dart' as app;

/// Global singleton — initialised once in main.dart via AudioService.init().
PlayedAudioHandler? globalAudioHandler;

class PlayedAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final Player _player = Player();

  List<app.MediaItem> _playlist      = [];
  int                 _queueIndex     = 0;
  bool                _loading        = false;
  int                 _loadGeneration = 0;

  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  double _speed       = 1.0;

  // Subscriptions to media_kit streams
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;

  PlayedAudioHandler() {
    // Emit playback state updates whenever playing/buffering/position changes.
    _playingSub = _player.stream.playing.listen((_) => _emitPlaybackState());
    _bufferingSub = _player.stream.buffering.listen((_) => _emitPlaybackState());
    // Throttle position updates to max 4/sec to avoid flooding the state stream.
    DateTime lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);
    _positionSub = _player.stream.position.listen((_) {
      final now = DateTime.now();
      if (now.difference(lastPositionEmit).inMilliseconds >= 250) {
        lastPositionEmit = now;
        _emitPlaybackState();
      }
    });
    _durationSub = _player.stream.duration.listen((_) => _emitPlaybackState());

    // Track completion — advance to next track.
    // NOTE: onSkipNext is wired by AudioPlayerNotifier and handles all
    // queue advancement. Do NOT call skipToNext() here to avoid double-skip.
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
        ));
        onSkipNext?.call();
      }
    });
  }

  Player get player => _player;

  Future<void> setPlaylist(
    List<app.MediaItem> items, {
    int    startIndex  = 0,
    double speed       = 1.0,
  }) async {
    _loadGeneration++;
    _playlist   = List.unmodifiable(items);
    _queueIndex = startIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    _speed      = speed;
    queue.add(_playlist.map(_toMediaItem).toList());
    if (_playlist.isNotEmpty) await _loadCurrent();
  }

  Future<void> loadAndPlay(
    app.MediaItem item, {
    double    speed         = 1.0,
    Duration? savedPosition,
  }) async {
    await setPlaylist([item], speed: speed);
    if (savedPosition != null && savedPosition.inSeconds > 0) {
      await _player.seek(savedPosition);
    }
  }

  @override Future<void> play()  => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> setSpeed(double speed) {
    _speed = speed;
    return _player.setRate(speed);
  }

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_queueIndex < _playlist.length - 1) {
      _queueIndex++;
      await _loadCurrent();
    } else {
      await _player.pause();
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
      ));
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    if (_player.state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_queueIndex > 0) {
      _queueIndex--;
      await _loadCurrent();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _queueIndex = index;
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final myGeneration = _loadGeneration;

    // FIX 1: Reset stale _loading flag instead of returning early.
    // The old guard caused a permanent deadlock when the user tapped a new
    // track while the previous one was still buffering — _loading stayed
    // true forever and silently blocked all future playback.
    if (_loading) {
      debugPrint('[AudioHandler] _loadCurrent: resetting stale _loading flag.');
      _loading = false;
    }

    if (_playlist.isEmpty) return;
    _loading = true;

    try {
      final item = _playlist[_queueIndex];

      mediaItem.add(_toMediaItem(item));
      playbackState.add(playbackState.value.copyWith(queueIndex: _queueIndex));

      if (_player.state.playing) await _player.pause();
      if (_loadGeneration != myGeneration) return;

      // FIX 2: Inner try/catch so a bad file path surfaces a clear error
      // and does NOT leave _loading = true forever via an early return that
      // bypasses the outer finally block.
      try {
        // media_kit's Media() accepts both file paths and content:// URIs
        // directly — no need to convert to Uri manually.
        await _player.open(
          Media(item.filePath),
          play: false,
        );
      } catch (srcErr) {
        debugPrint('[AudioHandler] player.open failed: $srcErr\nPath: ${item.filePath}');
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
        ));
        return; // falls through to finally -> _loading = false
      }

      if (_loadGeneration != myGeneration) return;

      await _player.setRate(_speed);
      // Note: media_kit does not support skip-silence natively; omitted.
      if (_loadGeneration != myGeneration) return;

      await play();
    } catch (e) {
      debugPrint('[AudioHandler] _loadCurrent error: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
    } finally {
      _loading = false;
    }
  }

  MediaItem _toMediaItem(app.MediaItem item) => MediaItem(
    id:       item.id,
    title:    item.title,
    artist:   item.artist ?? 'Unknown Artist',
    album:    item.album  ?? '',
    duration: item.duration,
    artUri:   item.albumArtPath != null &&
              !item.albumArtPath!.startsWith('albumid:')
        ? Uri.file(item.albumArtPath!)
        : null,
  );

  void _emitPlaybackState() {
    final buffering = _player.state.buffering;
    final playing   = _player.state.playing;
    final completed = _player.state.completed;

    final AudioProcessingState processingState;
    if (completed) {
      processingState = AudioProcessingState.completed;
    } else if (buffering) {
      processingState = AudioProcessingState.buffering;
    } else if (playing || _player.state.duration > Duration.zero) {
      processingState = AudioProcessingState.ready;
    } else {
      processingState = AudioProcessingState.idle;
    }

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing:          playing,
      updatePosition:   _player.state.position,
      bufferedPosition: _player.state.buffer,
      speed:            _player.state.rate,
      queueIndex:       _queueIndex,
    ));
  }

  Future<void> disposePlayer() async {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    try { await _player.dispose(); } catch (_) {}
  }
}
