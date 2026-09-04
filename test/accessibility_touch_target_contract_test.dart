import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile avatar keeps a 48dp semantic button target', () {
    final source = File(
      'lib/features/my_space/presentation/widgets/user_avatar_button.dart',
    ).readAsStringSync();

    expect(source, contains('IconButton('));
    expect(source, contains('tooltip: tooltip'));
    expect(
      source,
      contains('BoxConstraints.tightFor(width: 48, height: 48)'),
    );
    expect(source, isNot(contains('return GestureDetector(')));
  });

  test('battery saver is a semantic 48dp toggle', () {
    final source = File(
      'lib/features/player/presentation/widgets/battery_saver_toggle.dart',
    ).readAsStringSync();

    expect(source, contains('Semantics('));
    expect(source, contains('toggled: isActive'));
    expect(source, contains("label: 'Battery saver'"));
    expect(source, contains('InkWell('));
    expect(source, contains('BoxConstraints(minHeight: 48)'));
    expect(source, isNot(contains('return GestureDetector(')));
  });

  test('rating stars keep semantic 52dp targets', () {
    final source = File('lib/core/widgets/rate_us_sheet.dart').readAsStringSync();

    expect(source, contains('Semantics('));
    expect(source, contains("hint: 'Rate Otya \$rating out of 5'"));
    expect(source, contains('InkResponse('));
    expect(source, contains('width: 52'));
    expect(source, contains('height: 52'));
    expect(source, isNot(contains('return GestureDetector(')));
  });
}
