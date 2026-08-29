import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'media_dsp_service.dart';

/// Coordinates the single media player that is allowed to be active at once.
///
/// Players are observed after their first registration. If a previously
/// inactive player starts from a system media button, mini-player or another
/// UI path that calls `Player.play()` directly, the coordinator automatically
/// promotes it and pauses the previous owner. This keeps the one-player rule
/// true even when a caller forgets to register before playing.
class PlaybackCoordinator {
  PlaybackCoordinator._();
  static final PlaybackCoordinator instance = PlaybackCoordinator._();

  Player? _activePlayer;
  String? _activeType;
  double? _speedBeforeBoost;
  bool _switching = false;

  final Map<Player, String> _registeredTypes = <Player, String>{};
  final Map<Player, StreamSubscription<bool>> _playingSubscriptions =
      <Player, StreamSubscription<bool>>{};

  static const Duration pauseTimeout = Duration(seconds: 2);

  Player? get activePlayer => _activePlayer;
  String? get activeType => _activeType;

  Future<void> register(Player player, String type) async {
    _observe(player, type);
    if (_activePlayer == player) {
      _activeType = type;
      return;
    }

    if (_switching) return;
    _switching = true;
    try {
      final previous = _activePlayer;
      final previousType = _activeType;

      if (previous != null && previous != player && previous.state.playing) {
        debugPrint(
          '[PlaybackCoordinator] Pausing $previousType player before starting $type',
        );
        try {
          await previous.pause().timeout(
            pauseTimeout,
            onTimeout: () {
              debugPrint(
                '[PlaybackCoordinator] $previousType pause timed out after '
                '${pauseTimeout.inSeconds}s; continuing with $type',
              );
            },
          );
        } catch (e, st) {
          debugPrint(
            '[PlaybackCoordinator] Failed to pause $previousType player: $e\n$st',
          );
        }
      }

      _activePlayer = player;
      _activeType = type;
      _speedBeforeBoost = null;

      // DSP is optional and local to this MediaKit player. A filter failure is
      // never allowed to block playback or the owner switch itself.
      unawaited(MediaDspService.instance.applySaved(player));
      debugPrint('[PlaybackCoordinator] Registered $type player');
    } finally {
      _switching = false;
    }
  }

  void _observe(Player player, String type) {
    _registeredTypes[player] = type;
    if (_playingSubscriptions.containsKey(player)) return;

    _playingSubscriptions[player] = player.stream.playing.listen(
      (playing) {
        if (!playing || _activePlayer == player || _switching) return;
        final registeredType = _registeredTypes[player] ?? type;
        unawaited(register(player, registeredType));
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[PlaybackCoordinator] playing stream error: $error');
      },
    );
  }

  /// Temporarily boosts the active player's rate while the user holds a
  /// gesture. The previous rate is restored by [endSpeedBoost].
  Future<bool> beginSpeedBoost({double rate = 2.0}) async {
    final player = _activePlayer;
    if (player == null) return false;
    if (_speedBeforeBoost != null) return true;

    final currentRate = player.state.rate;
    _speedBeforeBoost = currentRate > 0 ? currentRate : 1.0;
    try {
      await player.setRate(rate);
      return true;
    } catch (e, st) {
      _speedBeforeBoost = null;
      debugPrint('[PlaybackCoordinator] Failed to boost speed: $e\n$st');
      return false;
    }
  }

  Future<void> endSpeedBoost() async {
    final player = _activePlayer;
    final previousRate = _speedBeforeBoost;
    _speedBeforeBoost = null;
    if (player == null || previousRate == null) return;

    try {
      await player.setRate(previousRate);
    } catch (e, st) {
      debugPrint('[PlaybackCoordinator] Failed to restore speed: $e\n$st');
    }
  }

  void unregister(Player player) {
    final subscription = _playingSubscriptions.remove(player);
    unawaited(subscription?.cancel());
    _registeredTypes.remove(player);

    if (_activePlayer == player) {
      _activePlayer = null;
      _activeType = null;
      _speedBeforeBoost = null;
      debugPrint('[PlaybackCoordinator] Unregistered player');
    }
  }
}
