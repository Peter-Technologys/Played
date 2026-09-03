import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent update checks share one in-flight request', () {
    final source =
        File('lib/core/services/update_service.dart').readAsStringSync();

    expect(source, contains('Future<UpdateInfo?>? _checkInFlight;'));
    expect(source, contains('final existing = _checkInFlight;'));
    expect(source, contains('final result = await existing;'));
    expect(source, contains('final check = _doCheckForUpdate(force: force);'));
    expect(source, contains('_checkInFlight = check;'));
    expect(source, contains('identical(_checkInFlight, check)'));
    expect(source, isNot(contains('bool _checkInProgress = false;')));
  });

  test('manual update checks are not swallowed by the 24-hour throttle', () {
    final source =
        File('lib/core/services/update_service.dart').readAsStringSync();

    expect(source, contains('final existingWasForced = _checkInFlightForced;'));
    expect(
      source,
      contains(
        'force && !existingWasForced && _lastState == UpdateCheckState.skipped',
      ),
    );
    expect(source, contains('return checkForUpdate(force: true);'));
  });
}
