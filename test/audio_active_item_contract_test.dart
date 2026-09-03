import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full audio player follows the active queue item after skips', () {
    final player = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();

    expect(
      player,
      contains(
        'final activeItem = ref.watch(miniPlayerItemProvider) ?? widget.mediaItem;',
      ),
    );
    expect(player, contains('albumArtPath: activeItem.albumArtPath'));
    expect(player, contains('activeItem.title'));
    expect(player, contains("activeItem.artist ?? 'Unknown Artist'"));
    expect(player, contains('[XFile(activeItem.filePath)]'));
    expect(player, contains('_startLoad(activeItem);'));
    expect(player, contains('savePosition(_activeItem.id)'));
  });

  test('album art resolution ignores stale async completions', () {
    final player = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains('int _resolveGeneration = 0;'));
    expect(player, contains('final generation = ++_resolveGeneration;'));
    expect(player, contains('generation != _resolveGeneration'));
  });
}
