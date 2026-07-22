import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/media_item.dart' as app;

/// Global singleton — initialised once in main.dart via AudioService.init().
PlayedAudioHandler? globalAudioHandler;

class PlayedAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  List<app.MediaItem> _playlist      = [];
  int                 _queueIndex     = 0;
  bool                _loading        = false;
  int                 _loadGeneration = 0;

  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  double _speed       = 1.0;
  bool   _skipSilence = false;

  PlayedAudioHandler() {
    _player.playbackEventStream.listen(
      (event) => playbackState.add(_transformEvent(event)),
      onError: (Object e) =>
          debugPrint('[AudioHandler] playbackEventStream error: $e'),
    );

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
        ));
        onSkipNext?.call();
      }
    });
  }

  AudioPlayer get player => _player;

  Future<void> setPlaylist(
    List<app.MediaItem> items, {
    int    startIndex  = 0,
    double speed       = 1.0,
    bool   skipSilence = false,
  }) async {
    _loadGeneration++;
    _playlist    = List.unmodifiable(items);
    _queueIndex  = startIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    _speed       = speed;
    _skipSilence = skipSilence;
    queue.add(_playlist.map(_toMediaItem).toList());
    if (_playlist.isNotEmpty) await _loadCurrent();
  }

  Future<void> loadAndPlay(
    app.MediaItem item, {
    double    speed         = 1.0,
    bool      skipSilence   = false,
    Duration? savedPosition,
  }) async {
    await setPlaylist([item], speed: speed, skipSilence: skipSilence);
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
    return _player.setSpeed(speed);
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
    if (_player.position.inSeconds > 3) {
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

      if (_player.playing) await _player.pause();
      if (_loadGeneration != myGeneration) return;

      // FIX 2: Inner try/catch so a bad file path surfaces a clear error
      // and does NOT leave _loading = true forever via an early return that
      // bypasses the outer finally block.
      try {
        // On Android 10+, MediaStore returns content:// URIs.
        // Uri.file('content://...') produces file:///content:/... which is
        // invalid. Parse content:// URIs directly; use Uri.file only for
        // plain file-system paths.
        final uri = item.filePath.startsWith('content://')
            ? Uri.parse(item.filePath)
            : Uri.file(item.filePath);
        await _player.setAudioSource(
          AudioSource.uri(uri),
          preload: true,
        );
      } catch (srcErr) {
        debugPrint('[AudioHandler] setAudioSource failed: $srcErr\nPath: ${item.filePath}');
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
        ));
        return; // falls through to finally -> _loading = false
      }

      if (_loadGeneration != myGeneration) return;

      await _player.setSpeed(_speed);
      await _player.setSkipSilenceEnabled(_skipSilence);
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

  PlaybackState _transformEvent(PlaybackEvent event) {
    final processingState = switch (_player.processingState) {
      ProcessingState.idle      => AudioProcessingState.idle,
      ProcessingState.loading   => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready     => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
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
      playing:          _player.playing,
      updatePosition:   _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed:            _player.speed,
      queueIndex:       _queueIndex,
    );
  }

  Future<void> disposePlayer() async {
    try { await _player.dispose(); } catch (_) {}
  }
}
