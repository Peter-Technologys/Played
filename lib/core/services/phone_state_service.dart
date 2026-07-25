import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges the Flutter `pauseDuringCalls` setting to the Kotlin
/// `com.otyaplayer.app/phone_state` MethodChannel.
///
/// Kotlin registers a `TelephonyManager` listener when `enabled` is true and
/// unregisters it when false. This service must be called:
///   1. On app startup (to apply the persisted setting).
///   2. Whenever the user toggles the setting in the Settings screen.
class PhoneStateService {
  PhoneStateService._();
  static final PhoneStateService instance = PhoneStateService._();

  static const _channel = MethodChannel('com.otyaplayer.app/phone_state');

  /// Tells Kotlin to register (enabled=true) or unregister (enabled=false)
  /// the phone-call listener that pauses playback during incoming calls.
  Future<void> setPauseDuringCalls(bool enabled) async {
    try {
      await _channel.invokeMethod<void>(
        'setPauseDuringCalls',
        {'enabled': enabled},
      );
      debugPrint('[PhoneState] setPauseDuringCalls: $enabled');
    } catch (e) {
      debugPrint('[PhoneState] error: $e');
    }
  }
}
