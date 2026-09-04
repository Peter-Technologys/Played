import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resuming in-app playback restores the system media session', () {
    final source = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();

    expect(source, contains('AudioHandlerSingleton.instance.attachPlayer(_player);'));
    expect(source, contains("register(_player, 'audio')"));
    expect(source, contains('AudioSessionService.instance.activate()'));
  });

  test('system playback claims focus and stop releases it', () {
    final source = File('lib/core/services/audio_handler.dart').readAsStringSync();

    expect(source, contains('AudioSessionService.instance.activate()'));
    expect(source, contains('AudioSessionService.instance.deactivate()'));
  });

  test('Android exposes a media playback foreground service', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(manifest, contains('com.ryanheise.audioservice.MediaButtonReceiver'));
  });
}
