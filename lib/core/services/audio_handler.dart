import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/media_item.dart' as app;

/// Global singleton — initialised once in main.dart via AudioService.init().
PlayedAudioHandler? globalAudioHandler;

/// PlayedAudioHandler — 2027 MediaPlaybackHandler.
///
/// Extends BaseAudioHandler with QueueHandler + SeekHandler so the Android
/// MediaSession notification drawer gets full interactive controls:
/// Play, Pause, Skip Next/Previous, and a scrubbable seek timeline.
///
/// Queue management:
///   The handler owns the playlist queue internally. When skipToNext() or
///   skipToPrevious() is called from the notification, it advances the
///   queue index, updates the MediaItem metadata (title, artist, art URI)
///   in the notification, and loads the new track — all without touching
///   the UI thread.
///
/// Performance:
///   • _loading guard prevents overlapping loadAndPlay calls.
///   • playbackEventStream is piped directly into the BehaviorSubject
///     — no intermediate StreamController allocation.
///   • switch expression for processingState is exhaustive and avoids
///     the null-fallback overhead of the old Map lookup.
class PlayedAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // ── Queue state ───────────────────────────────────────────────────────────────
  List<app.MediaItem> _playlist = [];
  int                 _queueIndex     = 0;
  bool                _loading        = false;
  // Incremented on every setPlaylist/loadAndPlay call so an in-flight
  // _loadCurrent can detect it has been superseded and bail out early,
  // fixing the race condition where rapid song taps caused the wrong
  // track to play.
  int                 _loadGeneration = 0;

  // Public callbacks — wired by AudioPlayerNotifier so notification /
  // lock-screen skip buttons advance the in-app queue automatically.
  // Restored: accidentally removed in the !62 QueueHandler rewrite.
  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  // Playback settings carried across track changes
  double _speed       = 1.0;
  bool   _skipSilence = false;

  PlayedAudioHandler() {
    // Listen to playback events and push into the BehaviorSubject.
    // Using listen() instead of pipe() avoids an unhandled Future rejection
    // when the stream closes during dispose.
    _player.playbackEventStream.listen(
      (event) => playbackState.add(_transformEvent(event)),
      onError: (Object e) =>
          debugPrint('[AudioHandler] playbackEventStream error: $e'),
    );

    // Update playbackState on completion. Auto-advance is intentionally NOT
    // done here — it is handled exclusively by AudioPlayerNotifier via the
    // onSkipNext callback, which respects repeat/shuffle state. Calling
    // skipToNext() here AND in the notifier caused double-skipping.
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
        ));
        // Notify the UI-side notifier so it can drive queue progression.
        onSkipNext?.call();
      }
    });
  }

  AudioPlayer get player => _player;

  // ── Queue management ───────────────────────────────────────────────────────────

  /// Replace the entire playlist and start playing from [startIndex].
  Future<void> setPlaylist(
    List<app.MediaItem> items, {
    int    startIndex  = 0,
    double speed       = 1.0,
    bool   skipSilence = false,
  }) async {
    // Bump generation so any in-flight _loadCurrent bails out early.
    _loadGeneration++;
    _playlist    = List.unmodifiable(items);
    _queueIndex  = startIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    _speed       = speed;
    _skipSilence = skipSilence;

    // Publish the full queue to the MediaSession so the notification
    // drawer can show queue metadata on supported Android versions.
    queue.add(_playlist.map(_toMediaItem).toList());

    if (_playlist.isNotEmpty) {
      await _loadCurrent();
    }
  }

  /// Load and play a single item (backwards-compatible with existing callers).
  Future<void> loadAndPlay(
    app.MediaItem item, {
    double   speed       = 1.0,
    bool     skipSilence = false,
    Duration? savedPosition,
  }) async {
    await setPlaylist([item], speed: speed, skipSilence: skipSilence);
    if (savedPosition != null && savedPosition.inSeconds > 0) {
      await _player.seek(savedPosition);
    }
  }

  // ── BaseAudioHandler overrides ───────────────────────────────────────────────────────

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

  /// Skip to next track in the queue.
  /// Updates the notification MediaItem metadata before loading.
  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_queueIndex < _playlist.length - 1) {
      _queueIndex++;
      await _loadCurrent();
    } else {
      // End of queue — pause and signal completion without dismissing the
      // notification (stop() sends a stop event that removes the drawer).
      await _player.pause();
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
      ));
    }
  }

  /// Skip to previous track in the queue.
  /// If more than 3 seconds have elapsed, seeks to start instead.
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

  /// Jump to a specific queue index (e.g. user taps a track in the playlist).
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _queueIndex = index;
    await _loadCurrent();
  }

  // ── Internal helpers ───────────────────────────────────────────────────────────────

  Future<void> _loadCurrent() async {
    // Capture generation at entry; bail out if superseded by a newer call.
    final myGeneration = _loadGeneration;

    if (_loading) {
      debugPrint('[AudioHandler] _loadCurrent skipped — already loading.');
      return;
    }
    if (_playlist.isEmpty) return;
    _loading = true;
    try {
      final item = _playlist[_queueIndex];

      // Update the notification MediaItem BEFORE loading so the drawer
      // shows the new title/art immediately without waiting for buffering.
      mediaItem.add(_toMediaItem(item));

      // Publish the current queue index so the notification can highlight
      // the active track in queue-aware launchers.
      playbackState.add(playbackState.value.copyWith(
        queueIndex: _queueIndex,
      ));

      if (_player.playing) await _player.pause();
      if (_loadGeneration != myGeneration) return; // superseded

      await _player.setAudioSource(
        AudioSource.uri(Uri.file(item.filePath)),
        preload: true,
      );
      if (_loadGeneration != myGeneration) return; // superseded

      await _player.setSpeed(_speed);
      await _player.setSkipSilenceEnabled(_skipSilence);
      if (_loadGeneration != myGeneration) return; // superseded

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

  /// Convert an app.MediaItem to the audio_service MediaItem format.
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
