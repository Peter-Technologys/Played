import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/media_item.dart' as app;

/// Global singleton — initialised once in main.dart via AudioService.init().
PlayedAudioHandler? globalAudioHandler;

class PlayedAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// Callbacks wired by AudioPlayerNotifier so notification / lock screen
  /// skip buttons advance the in-app queue automatically.
  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  PlayedAudioHandler() {
    _player.playbackEventStream
        .map(_transformEvent)
        .pipe(playbackState)
        .catchError((e) {
      debugPrint('[AudioHandler] playbackEventStream error: $e');
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
        ));
      }
    });
  }

  AudioPlayer get player => _player;

  Future<void> loadAndPlay(
    app.MediaItem item, {
    double speed = 1.0,
    bool skipSilence = false,
    Duration? savedPosition,
  }) async {
    try {
      mediaItem.add(MediaItem(
        id:       item.id,
        title:    item.title,
        artist:   item.artist ?? 'Unknown Artist',
        album:    item.album ?? '',
        duration: item.duration,
        artUri:   item.albumArtPath != null &&
                  !item.albumArtPath!.startsWith('albumid:')
            ? Uri.file(item.albumArtPath!)
            : null,
      ));

      // Stop any currently playing track cleanly before loading a new one.
      // This prevents audio bleed-through when switching tracks quickly.
      if (_player.playing) {
        await _player.stop();
      }

      // Use AudioSource.uri with a proper file:// URI.
      // setFilePath() can silently fail on some Android versions.
      await _player.setAudioSource(
        AudioSource.uri(Uri.file(item.filePath)),
        preload: true,
      );

      if (savedPosition != null && savedPosition.inSeconds > 0) {
        await _player.seek(savedPosition);
      }
      await _player.setSpeed(speed);
      await _player.setSkipSilenceEnabled(skipSilence);
      await play();
    } catch (e) {
      debugPrint('[AudioHandler] loadAndPlay error: $e');
      // Emit an idle state so the UI stops showing a spinner
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      rethrow; // Let AudioPlayerNotifier handle the error state
    }
  }

  @override Future<void> play()  => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> setSpeed(double speed)  => _player.setSpeed(speed);
  @override Future<void> skipToNext()     async => onSkipNext?.call();
  @override Future<void> skipToPrevious() async => onSkipPrevious?.call();

  Future<void> disposePlayer() async {
    try { await _player.dispose(); } catch (_) {}
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    final processingState = {
      ProcessingState.idle:      AudioProcessingState.idle,
      ProcessingState.loading:   AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready:     AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState] ?? AudioProcessingState.idle;

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
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing:          _player.playing,
      updatePosition:   _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed:            _player.speed,
      queueIndex:       event.currentIndex,
    );
  }
}
