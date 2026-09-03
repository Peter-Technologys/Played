import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void expectNotContains(String source, String needle) {
  expect(source.contains(needle), isFalse);
}

void main() {
  test('Now Playing metadata is queued until the audio handler is ready', () {
    final handler = File('lib/core/services/audio_handler.dart').readAsStringSync();
    final notifications = File('lib/core/services/media_notification_service.dart')
        .readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(handler, contains('MediaItem? _pendingMediaItem'));
    expect(handler, contains('bool? _pendingPlaying'));
    expect(handler, contains('Queued Now Playing metadata'));
    expect(notifications, contains('AudioHandlerSingleton.instance.setMediaItem'));
    expect(notifications, contains('AudioHandlerSingleton.instance.setPlaying'));
    expectNotContains(handler, "album: 'OTYA Player'");
    expect(main, contains("androidNotificationChannelName: 'Otya — Now Playing'"));
    expect(main, contains('notificationColor: const Color(0xFF2979FF)'));
  });

  test('crash reporting is installed once before the first frame', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('await CrashReporter.instance.init();'));
    expectNotContains(main, "_safeBackground('crash reporter'");
    expectNotContains(main, 'FlutterError.onError = (details)');
    expectNotContains(main, 'PlatformDispatcher.instance.onError =');
  });

  test('update checks do not pretend disabled or failed checks mean current', () {
    final updates = File('lib/core/services/update_service.dart').readAsStringSync();

    expectNotContains(updates, 'if (!Environment.selfUpdateEnabled) return null;');
    expect(updates, contains('UpdateCheckState.unavailable'));
    expect(updates, contains('UpdateCheckState.current'));
    expect(updates, contains('UpdateCheckState.updateAvailable'));
  });

  test('media refreshes share one in-flight scan without orphaned errors', () {
    final repository =
        File('lib/features/my_space/data/media_repository.dart').readAsStringSync();

    expect(repository, contains('Future<List<MediaItem>>? _scanInFlight'));
    expect(repository, contains('final existingScan = _scanInFlight'));
    expect(repository, contains('if (existingScan != null) return existingScan;'));
    expect(repository, contains('if (identical(_scanInFlight, scan))'));
    expectNotContains(repository, 'Completer<List<MediaItem>>');
    expectNotContains(repository, 'completeError(e)');
  });

  test('video retry releases failed native player before replacement', () {
    final engine =
        File('lib/core/services/media_kit_engine.dart').readAsStringSync();

    expect(engine, contains('final generation = ++_playerGeneration'));
    expect(engine, contains('Future<void> _releaseCurrentPlayer()'));
    expect(engine, contains('await _releaseCurrentPlayer();'));
    expect(engine, contains('await player.dispose();'));
    expect(engine, contains('onPressed: _retrying ? null : _retryPlayer'));
    expectNotContains(
      engine,
      "onPressed: () {\n                      setState(() { _hasError = false;",
    );
  });
}
