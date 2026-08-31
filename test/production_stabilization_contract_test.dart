import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Now Playing metadata is queued until the audio handler is ready', () {
    final handler = File('lib/core/services/audio_handler.dart').readAsStringSync();
    final notifications = File('lib/core/services/media_notification_service.dart')
        .readAsStringSync();

    expect(handler, contains('MediaItem? _pendingMediaItem'));
    expect(handler, contains('bool? _pendingPlaying'));
    expect(handler, contains('Queued Now Playing metadata'));
    expect(notifications, contains('AudioHandlerSingleton.instance.setMediaItem'));
    expect(notifications, contains('AudioHandlerSingleton.instance.setPlaying'));
    expect(handler, isNot(contains("album: 'OTYA Player'")));
  });

  test('crash reporting is installed once before the first frame', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('await CrashReporter.instance.init();'));
    expect(main, isNot(contains("_safeBackground('crash reporter'")));
    expect(main, isNot(contains('FlutterError.onError = (details)')));
    expect(main, isNot(contains('PlatformDispatcher.instance.onError =')));
  });

  test('update checks do not pretend disabled or failed checks mean current', () {
    final updates = File('lib/core/services/update_service.dart').readAsStringSync();

    expect(updates, isNot(contains('if (!Environment.selfUpdateEnabled) return null;')));
    expect(updates, contains('UpdateCheckState.unavailable'));
    expect(updates, contains('UpdateCheckState.current'));
    expect(updates, contains('UpdateCheckState.updateAvailable'));
  });
}
