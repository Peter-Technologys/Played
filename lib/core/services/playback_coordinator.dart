import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Coordinates the single media player that is allowed to be active at once.
/// A stuck previous player must never block registration of the next player.
class PlaybackCoordinator {
  PlaybackCoordinator._();
  static final PlaybackCoordinator instance = PlaybackCoordinator._();

  Player? _activePlayer;
  String? _activeType;

  static const Duration pauseTimeout = Duration(seconds: 2);

  Player? get activePlayer => _activePlayer;

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
    debugPrint('[PlaybackCoordinator] Registered $type player');
  }

  void unregister(Player player) {
    if (_activePlayer == player) {
      _activePlayer = null;
      _activeType = null;
      debugPrint('[PlaybackCoordinator] Unregistered player');
    }
  }
}
