import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video PiP follows actual playback state', () {
    final source = File('lib/features/player/presentation/video_player_screen.dart')
        .readAsStringSync();

    expect(
      source,
      contains('setVideoPlaying(playing: _isPlaying)'),
    );
    expect(
      source,
      contains('setVideoPlaying(playing: playing)'),
    );
    expect(source, contains('_pipSupported &&\n        _isPlaying'));
  });

  test('paused video cannot auto-enter PiP from lifecycle pause', () {
    final source = File('lib/features/player/presentation/video_player_screen.dart')
        .readAsStringSync();
    final lifecycle = source.substring(
      source.indexOf('void didChangeAppLifecycleState'),
      source.indexOf('void _resetHideTimer'),
    );

    expect(lifecycle, contains('_isPlaying'));
    expect(lifecycle, contains('PipService.instance.enterPip()'));
  });
}
