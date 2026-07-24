import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Singleton that tracks the currently active media_kit Player.
/// When a new player starts, it pauses the previous one.
/// This prevents audio + video playing simultaneously.
class PlaybackCoordinator {
  PlaybackCoordinator._();
  static final PlaybackCoordinator instance = PlaybackCoordinator._();

  Player? _activePlayer;
  String? _activeType; // 'audio' or 'video'

  /// Call this when a player is about to start playing.
  /// Pauses any other active player first.
  Future<void> register(Player player, String type) async {
    if (_activePlayer != null &&
        _activePlayer != player &&
        _activePlayer!.state.playing) {
      debugPrint('[PlaybackCoordinator] Pausing $_activeType player to start $type');
      try { await _activePlayer!.pause(); } catch (_) {}
    }
    _activePlayer = player;
    _activeType = type;
  }

  /// Call this when a player is disposed.
  void unregister(Player player) {
    if (_activePlayer == player) {
      _activePlayer = null;
      _activeType = null;
    }
  }
}
