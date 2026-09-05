import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full audio player follows the active queue item after skips', () {
    final screen = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();
    final nowPlaying = File(
      'lib/features/player/presentation/widgets/audio_player_now_playing_view.dart',
    ).readAsStringSync();
    final player = '$screen\n$nowPlaying';

    expect(
      screen,
      contains(
        'final activeItem = ref.watch(miniPlayerItemProvider) ?? widget.mediaItem;',
      ),
    );
    expect(player, contains('albumArtPath: activeItem.albumArtPath'));
    expect(player, contains('activeItem.title'));
    expect(player, contains("activeItem.artist ?? 'Unknown Artist'"));
    expect(player, contains('[XFile(activeItem.filePath)]'));
    expect(screen, contains('_startLoad(activeItem);'));
    expect(screen, contains('savePosition(_activeItem.id)'));
  });

  test('album art resolution ignores stale async completions', () {
    final player = File(
      'lib/features/player/presentation/widgets/audio_player_widgets.dart',
    ).readAsStringSync();

    expect(player, contains('int _resolveGeneration = 0;'));
    expect(player, contains('final generation = ++_resolveGeneration;'));
    expect(player, contains('generation != _resolveGeneration'));
  });
}