import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post-frame services parallelize without weakening startup dependencies', () {
    final source = File('lib/main.dart').readAsStringSync();

    final playback = source.indexOf(
      "await _safeBackground('playback platform', _initPlaybackPlatform);",
    );
    final notifications = source.indexOf('final notificationsReady =');
    final storage = source.indexOf('final storageReady =');
    final connectivity = source.indexOf('final connectivityReady =');
    final cache = source.indexOf('final cacheReady =');
    final audioSession = source.indexOf('final audioSessionReady =');
    final firebase = source.indexOf('final firebaseReady =');
    final wait = source.indexOf('await Future.wait<void>([');

    expect(playback, greaterThanOrEqualTo(0));
    expect(notifications, greaterThan(playback));
    expect(storage, greaterThan(playback));
    expect(connectivity, greaterThan(playback));
    expect(cache, greaterThan(playback));
    expect(audioSession, greaterThan(playback));
    expect(firebase, greaterThan(playback));
    expect(wait, greaterThan(firebase));

    expect(
      source,
      contains(
        "connectivityReady.then(\n      (_) => _safeBackground('update check', UpdateService.instance.checkAndNotify),",
      ),
    );
    expect(
      source,
      contains(
        "firebaseReady.then(\n      (_) => _safeBackground('FCM', FcmService.instance.init),",
      ),
    );
    expect(
      source,
      contains(
        "cacheReady.then(\n      (_) => _safeBackground('cache eviction', CacheService.instance.evictExpired),",
      ),
    );
  });
}
