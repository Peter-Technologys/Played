import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/media_item.dart' as app;

/// Global singleton — initialised once in main.dart via AudioService.init().
PlayedAudioHandler? globalAudioHandler;

/// Wraps just_audio inside audio_service so Android shows a
/// lockscreen / notification media player with:
///   - Track title, artist, album art
///   - Play / Pause / Skip Previous / Skip Next buttons
///   - Seek bar on the lock screen
///   - Works from Bluetooth headsets and car audio
class PlayedAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  PlayedAudioHandler() {
    // Forward just_audio state → audio_service playback state
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  // ── Public API used by the Flutter UI ──────────────────────────────────────────

  AudioPlayer get player => _player;

  Future<void> loadAndPlay(
    app.MediaItem item, {
    double speed = 1.0,
    bool skipSilence = false,
    Duration? savedPosition,
  }) async {
    // Update the media item shown in the notification / lock screen
    mediaItem.add(MediaItem(
      id: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      album: item.album ?? '',
      duration: item.duration,
      // albumArtPath may be an 'albumid:12345' virtual MediaStore ID,
      // not a real file path — only pass real file paths to Uri.file().
      artUri: item.albumArtPath != null &&
              !item.albumArtPath!.startsWith('albumid:')
          ? Uri.file(item.albumArtPath!)
          : null,
    ));

    try {
      await _player.setFilePath(item.filePath);
      if (savedPosition != null && savedPosition.inSeconds > 0) {
        await _player.seek(savedPosition);
      }
      await _player.setSpeed(speed);
      await _player.setSkipSilenceEnabled(skipSilence);
      await play();
    } catch (e) {
      debugPrint('[AudioHandler] loadAndPlay error: $e');
    }
  }

  // ── BaseAudioHandler overrides ──────────────────────────────────────────────────

  @override Future<void> play()  => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> stop()  async { await _player.stop(); await super.stop(); }
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> setSpeed(double speed)  => _player.setSpeed(speed);

  @override
  Future<void> skipToNext()     async {} // handled by UI queue
  @override
  Future<void> skipToPrevious() async {} // handled by UI queue

  // ── State transform ────────────────────────────────────────────────────────────

  PlaybackState _transformEvent(PlaybackEvent event) {
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
      processingState: const {
        ProcessingState.idle:      AudioProcessingState.idle,
        ProcessingState.loading:   AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready:     AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
