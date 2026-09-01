import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File(
    'lib/features/music/online/online_music_service.dart',
  ).readAsStringSync();
  final screen = File(
    'lib/features/music/online/online_music_screen.dart',
  ).readAsStringSync();

  test('identical online music requests share one in-flight future', () {
    expect(
      service,
      contains('final Map<String, Future<List<OnlineTrack>>> _inFlight = {};'),
    );
    expect(service, contains('final existing = _inFlight[cacheKey];'));
    expect(service, contains('if (existing != null) return existing;'));
    expect(service, contains('_inFlight[cacheKey] = request;'));
    expect(service, contains('_inFlight.remove(cacheKey);'));
  });

  test('online music retry preserves the active search query', () {
    expect(screen, contains('Future<List<OnlineTrack>> _requestForCurrentQuery()'));
    expect(screen, contains('OnlineMusicService.instance.search(query)'));
    expect(
      screen,
      contains('() => _tracks = _requestForCurrentQuery(),'),
    );
    expect(
      screen,
      isNot(
        contains(
          '() => _tracks = OnlineMusicService.instance.discover(),',
        ),
      ),
    );
  });
}
