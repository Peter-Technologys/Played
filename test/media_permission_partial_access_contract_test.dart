import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 13+ accepts either audio or video permission', () {
    final source =
        File('lib/core/permissions/permission_helper.dart').readAsStringSync();

    expect(source, contains('statuses.values.any(_usable)'));
    expect(source, contains('return _usable(audio) || _usable(videos);'));
    expect(source, isNot(contains('statuses.values.every(')));
  });
}
