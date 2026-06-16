import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/media_item.dart' as app;

/// Global singleton — initialised once in main.dart via AudioService.init().
PlayedAudioHandler? globalAudioHandler;

class PlayedAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

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

      await _player.setFilePath(item.filePath);

      if (savedPosition != null && savedPosition.inSeconds > 0) {
        await _player.seek(savedPosition);
      }
      await _player.setSpeed(speed);
      await _player.setSkipSilenceEnabled(skipSilence);
      await play();
    } catch (e) {
      debugPrint('[AudioHandler] loadAndPlay error: $e');
      // Don't rethrow — let the UI show the error state gracefully
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
  @override Future<void> skipToNext()     async {}
  @override Future<void> skipToPrevious() async {}

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
