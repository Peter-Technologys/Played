import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'playback_coordinator.dart';

/// Owns OTYA's app-wide audio focus and interruption policy.
///
/// Android exposes one shared audio-focus contract for the app. Keeping the
/// policy here prevents the MediaKit player, background audio service and
/// platform bridge from competing over focus independently.
class AudioSessionService {
  AudioSessionService._();
  static final AudioSessionService instance = AudioSessionService._();

  AudioSession? _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;
  bool _initialized = false;
  bool _pauseDuringCalls = true;
  bool _resumeAfterInterruption = false;
  double? _volumeBeforeDuck;

  Future<void> init({required bool pauseDuringCalls}) async {
    if (!_initialized) {
      final session = await AudioSession.instance;
      _session = session;
      await session.configure(AudioSessionConfiguration.music());

      // Output becoming noisy (wired/Bluetooth audio disappears) is always
      // handled. This avoids suddenly routing active playback to the speaker.
      _noisySub = session.becomingNoisyEventStream.listen(
        (_) => unawaited(_pauseForNoisyOutput()),
        onError: (Object error, StackTrace stack) {
          debugPrint('[AudioSession] noisy stream error: $error');
        },
      );
      _initialized = true;
    }

    await setPauseDuringCalls(pauseDuringCalls);
    debugPrint(
      '[AudioSession] configured; pauseDuringCalls=$_pauseDuringCalls.',
    );
  }

  Future<void> setPauseDuringCalls(bool enabled) async {
    _pauseDuringCalls = enabled;
    if (!_initialized) {
      await init(pauseDuringCalls: enabled);
      return;
    }

    if (enabled) {
      if (_interruptionSub != null) return;
      final session = _session ?? await AudioSession.instance;
      _interruptionSub = session.interruptionEventStream.listen(
        _handleInterruption,
        onError: (Object error, StackTrace stack) {
          debugPrint('[AudioSession] interruption stream error: $error');
        },
      );
      return;
    }

    await _interruptionSub?.cancel();
    _interruptionSub = null;
    _resumeAfterInterruption = false;

    final previous = _volumeBeforeDuck;
    _volumeBeforeDuck = null;
    final player = PlaybackCoordinator.instance.activePlayer;
    if (previous != null && player != null) {
      try {
        await player.setVolume(previous);
      } catch (error) {
        debugPrint('[AudioSession] volume restore failed: $error');
      }
    }
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    if (!_pauseDuringCalls) return;
    final player = PlaybackCoordinator.instance.activePlayer;
    if (player == null) return;

    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _volumeBeforeDuck ??= player.state.volume;
          unawaited(
            player.setVolume(
              (player.state.volume * .35).clamp(0.0, 100.0),
            ),
          );
          break;
        case AudioInterruptionType.pause:
          _resumeAfterInterruption = player.state.playing;
          if (_resumeAfterInterruption) unawaited(player.pause());
          break;
        case AudioInterruptionType.unknown:
          _resumeAfterInterruption = false;
          if (player.state.playing) unawaited(player.pause());
          break;
      }
      return;
    }

    switch (event.type) {
      case AudioInterruptionType.duck:
        final previous = _volumeBeforeDuck;
        _volumeBeforeDuck = null;
        if (previous != null) unawaited(player.setVolume(previous));
        break;
      case AudioInterruptionType.pause:
        if (_resumeAfterInterruption) {
          _resumeAfterInterruption = false;
          unawaited(player.play());
        }
        break;
      case AudioInterruptionType.unknown:
        _resumeAfterInterruption = false;
        break;
    }
  }

  Future<void> _pauseForNoisyOutput() async {
    final player = PlaybackCoordinator.instance.activePlayer;
    if (player == null || !player.state.playing) return;
    _resumeAfterInterruption = false;
    await player.pause();
    debugPrint('[AudioSession] paused after audio output became noisy.');
  }

  Future<void> dispose() async {
    await _interruptionSub?.cancel();
    await _noisySub?.cancel();
    _interruptionSub = null;
    _noisySub = null;
    _session = null;
    _initialized = false;
  }
}
