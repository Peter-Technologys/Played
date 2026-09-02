import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio loads only finalize the current successful generation', () {
    final source = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Future<bool> _loadCurrent('));
    expect(source, contains('final generation = ++_loadGeneration;'));
    expect(source, contains('required int generation'));
    expect(
      source,
      contains('_loadGeneration == generation && _currentItemId == item.id'),
    );
    expect(source, contains('final loaded = await _loadCurrent('));
    expect(source, contains('if (!loaded ||'));
    expect(source, contains('OtyaDatabase.instance.recordPlay(item).ignore();'));

    final failedOpen = RegExp(
      r'player\.open failed:[\s\S]*?return false;',
    );
    expect(source, matches(failedOpen));
  });

  test('ten-second rewind never seeks before zero', () {
    final source = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('target.isNegative ? Duration.zero : target'),
    );
    expect(
      source,
      isNot(contains(
        '_player.seek(state.position - const Duration(seconds: 10))',
      )),
    );
  });
}
