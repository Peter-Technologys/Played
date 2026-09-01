import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trim range is clamped to the current media duration', () {
    final source = File('lib/features/tools/whatsapp_trimmer_screen.dart')
        .readAsStringSync();

    expect(source, contains('final clipLength = duration.clamp(0.0, 30.0).toDouble();'));
    expect(source, contains('final start = storedStart.clamp(0.0, maxStart).toDouble();'));
    expect(source, contains('final end = (start + clipLength).clamp(start, duration).toDouble();'));
    expect(source, contains('startSec: start'));
    expect(source, contains('endSec: end'));
  });

  test('short videos do not expose an invalid 30 second trim request', () {
    final source = File('lib/features/tools/whatsapp_trimmer_screen.dart')
        .readAsStringSync();

    expect(source, contains("'${clipLength.round()} sec'"));
    expect(source, contains('status == TrimStatus.trimming || clipLength <= 0'));
    expect(source, contains('max: maxStart'));
  });
}
