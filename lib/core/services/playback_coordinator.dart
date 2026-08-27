import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Coordinates the single media player that is allowed to be active at once.
/// A stuck previous player must never block registration of the next player.
class PlaybackCoordinator {
  PlaybackCoordinator._();
  static final PlaybackCoordinator instance = PlaybackCoordinator._();

  Player? _activePlayer;
  String? _activeType;
  double? _speedBeforeBoost;

  static const Duration pauseTimeout = Duration(seconds: 2);

  Player? get activePlayer => _activePlayer;
  String? get activeType => _activeType;

  Future<void> register(Player player, String type) async {
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
    debugPrint('[PlaybackCoordinator] Registered $type player');
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
    if (_activePlayer == player) {
      _activePlayer = null;
      _activeType = null;
      _speedBeforeBoost = null;
      debugPrint('[PlaybackCoordinator] Unregistered player');
    }
  }
}
