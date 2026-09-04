import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String section(String source, String start, String end) {
  final from = source.indexOf(start);
  final to = source.indexOf(end, from + start.length);
  expect(from, greaterThanOrEqualTo(0));
  expect(to, greaterThan(from));
  return source.substring(from, to);
}

void main() {
  test('audio utility controls keep semantic 48dp-or-larger touch targets', () {
    final source = File(
      'lib/features/player/presentation/widgets/audio_player_widgets.dart',
    ).readAsStringSync();

    final toggle = section(source, 'class _ToggleIconBtn', 'class _RepeatBtn');
    expect(toggle, contains('IconButton('));
    expect(toggle, contains('tooltip: tooltip'));
    expect(
      toggle,
      contains('BoxConstraints.tightFor(width: 48, height: 48)'),
    );
    expect(toggle, isNot(contains('return GestureDetector(')));

    final repeat = section(source, 'class _RepeatBtn', 'class _SecondaryBtn');
    expect(repeat, contains('IconButton('));
    expect(repeat, contains('tooltip: tooltip'));
    expect(
      repeat,
      contains('BoxConstraints.tightFor(width: 48, height: 48)'),
    );
    expect(repeat, isNot(contains('return GestureDetector(')));

    final secondary = section(source, 'class _SecondaryBtn', 'class _OptionsSheet');
    expect(secondary, contains('Tooltip('));
    expect(secondary, contains('Semantics('));
    expect(secondary, contains('button: true'));
    expect(secondary, contains('InkWell('));
    expect(
      secondary,
      contains('BoxConstraints(minWidth: 56, minHeight: 64)'),
    );
    expect(secondary, isNot(contains('return GestureDetector(')));
  });
}
