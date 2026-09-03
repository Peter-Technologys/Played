import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio notifier delegates notification artwork ordering to one service', () {
    final player = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();
    final notifications = File(
      'lib/core/services/media_notification_service.dart',
    ).readAsStringSync();

    expect(player, contains('albumArtPath: item.albumArtPath'));
    expect(player, isNot(contains('String? _lastNotificationItemId;')));
    expect(player, isNot(contains('String? _lastResolvedArtPath;')));
    expect(
      player,
      isNot(contains('AlbumArtService.instance.resolve(item.albumArtPath).then')),
    );

    expect(notifications, contains('int _metadataGeneration = 0;'));
    expect(notifications, contains('final generation = ++_metadataGeneration;'));
    expect(notifications, contains('if (generation != _metadataGeneration) return;'));
  });
}
