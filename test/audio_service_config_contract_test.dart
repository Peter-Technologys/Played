import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio service notification configuration is assertion-safe', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('androidStopForegroundOnPause: false'));
    expect(source, contains('androidNotificationOngoing: false'));
    expect(
      source,
      isNot(
        contains(
          'androidNotificationOngoing: true,\n'
          '      androidStopForegroundOnPause: false',
        ),
      ),
    );
  });
}
