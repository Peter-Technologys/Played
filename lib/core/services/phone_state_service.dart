import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'playback_coordinator.dart';

/// Bridges Android telephony events to OTYA's single active MediaKit player.
///
/// Android is responsible only for observing call state. Playback authority
/// stays in Dart through [PlaybackCoordinator], so calls affect audio and video
/// consistently and OTYA can resume only when it was actually playing before
/// the interruption.
class PhoneStateService {
  PhoneStateService._();
  static final PhoneStateService instance = PhoneStateService._();

  static const _channel = MethodChannel('com.otyaplayer.app/phone_state');

  bool _handlerInstalled = false;
  bool _resumeAfterCall = false;

  Future<void> init({required bool enabled}) async {
    _installHandler();
    await setPauseDuringCalls(enabled);
  }

  void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'callState') return;
      final state = call.arguments is Map
          ? (call.arguments as Map)['state'] as int?
          : call.arguments as int?;
      if (state == null) return;

      // Android TelephonyManager states: 0 idle, 1 ringing, 2 off-hook.
      if (state == 1 || state == 2) {
        final player = PlaybackCoordinator.instance.activePlayer;
        if (player == null) return;
        _resumeAfterCall = player.state.playing;
        if (_resumeAfterCall) {
          try {
            await player.pause();
          } catch (error) {
            debugPrint('[PhoneState] pause failed: $error');
          }
        }
        return;
      }

      if (state == 0 && _resumeAfterCall) {
        _resumeAfterCall = false;
        final player = PlaybackCoordinator.instance.activePlayer;
        if (player == null) return;
        try {
          await player.play();
        } catch (error) {
          debugPrint('[PhoneState] resume failed: $error');
        }
      }
    });
  }

  /// Tells Kotlin to register (enabled=true) or unregister (enabled=false)
  /// the phone-call observer. This does not itself own playback state.
  Future<void> setPauseDuringCalls(bool enabled) async {
    _installHandler();
    if (!enabled) _resumeAfterCall = false;
    try {
      await _channel.invokeMethod<void>(
        'setPauseDuringCalls',
        {'enabled': enabled},
      );
      debugPrint('[PhoneState] setPauseDuringCalls: $enabled');
    } catch (error) {
      debugPrint('[PhoneState] error: $error');
    }
  }
}
