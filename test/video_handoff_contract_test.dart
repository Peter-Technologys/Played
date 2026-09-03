import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video next and previous use an in-player handoff', () {
    final player = File(
      'lib/features/player/presentation/video_player_screen.dart',
    ).readAsStringSync();

    expect(player, contains('bool _handoffToAnotherVideo = false;'));
    expect(player, contains('void _openQueuedVideo(MediaItem item)'));
    expect(player, contains('saveSeekPosition(widget.mediaItem.id, _position)'));
    expect(player, contains("context.pushReplacement('/player/video', extra: item);"));
    expect(player, contains('if (!_handoffToAnotherVideo)'));
    expect(player, isNot(contains("Navigator.of(context).pop();\n                              context.push('/player/video'")));
  });

  test('video overlay avoids filename-based HDR claims and duplicate trim controls', () {
    final player = File(
      'lib/features/player/presentation/video_player_screen.dart',
    ).readAsStringSync();

    expect(player, isNot(contains("filePath.toLowerCase().contains('hdr')")));
    expect(RegExp("tooltip: 'Trim video'").allMatches(player).length, 0);
    expect(player, contains("'Trim Video'"));
  });
}
