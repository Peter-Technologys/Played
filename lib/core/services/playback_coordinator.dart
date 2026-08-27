import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Singleton that tracks the currently active media_kit Player.
/// When a new player starts, it pauses the previous one.
/// This prevents audio + video playing simultaneously.
/// 
/// FIX: Added timeout to prevent app freezing when pause() hangs.
class PlaybackCoordinator {
  PlaybackCoordinator._();
  static final PlaybackCoordinator instance = PlaybackCoordinator._();

  Player? _activePlayer;
  String? _activeType; // 'audio' or 'video'
  
  // FIX: Track pause timeout to prevent hanging
  static const Duration PAUSE_TIMEOUT = Duration(seconds: 2);

  /// The currently active media_kit [Player], or null if nothing is playing.
  /// Used by [MediaNotificationService] to route notification action buttons
  /// (prev / play-pause / next) to the correct player instance.
  Player? get activePlayer => _activePlayer;

  /// Call this when a player is about to start playing.
  /// Pauses any other active player first.
  /// 
  /// FIX: Added timeout so switching audio→video doesn't freeze app
  /// if network is interrupted or player is stuck.
  Future<void> register(Player player, String type) async {
    if (_activePlayer != null &&
        _activePlayer != player &&
        _activePlayer!.state.playing) {
      debugPrint('[PlaybackCoordinator] Pausing $_activeType player to start $type');
      
      // FIX: Wrap pause() in timeout to prevent hanging
      try {
        await _activePlayer!.pause().timeout(
          PAUSE_TIMEOUT,
          onTimeout: () {
            debugPrint('[PlaybackCoordinator] Old player pause timed out after ${PAUSE_TIMEOUT.inSeconds}s, forcing registration');
            return; // Don't throw, just continue
          },
        );
      } catch (e) {
        debugPrint('[PlaybackCoordinator] Failed to pause old player: $e');
        // Continue anyway — don't block new player registration
      }
    }
    _activePlayer = player;
    _activeType = type;
    debugPrint('[PlaybackCoordinator] Registered $type player (paused old $_activeType)');
  }

  /// Call this when a player is disposed.
  void unregister(Player player) {
    if (_activePlayer == player) {
      _activePlayer = null;
      _activeType = null;
      debugPrint('[PlaybackCoordinator] Unregistered player');
    }
  }
}
