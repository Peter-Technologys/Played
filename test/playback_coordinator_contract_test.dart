import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playback ownership switches are serialized instead of dropped', () {
    final source = File('lib/core/services/playback_coordinator.dart')
        .readAsStringSync();

    expect(
      source,
      contains('Future<void> _switchQueue = Future<void>.value();'),
    );
    expect(
      source,
      contains('_switchQueue.then((_) => _registerNow(player, type))'),
    );
    expect(
      source,
      contains('if (!_registeredTypes.containsKey(player)) return;'),
    );
    expect(
      source,
      isNot(contains('if (_switching) return;')),
      reason: 'A concurrent registration must queue, not be discarded.',
    );
    expect(
      source,
      isNot(contains('_activePlayer == player || _switching')),
      reason: 'Playing events during a switch must still be serialized.',
    );
  });

  test('player switch retains bounded pause behavior', () {
    final source = File('lib/core/services/playback_coordinator.dart')
        .readAsStringSync();

    expect(
      source,
      contains('static const Duration pauseTimeout = Duration(seconds: 2);'),
    );
    expect(source, contains('previous.pause().timeout('));
    expect(source, contains('pauseTimeout,'));
  });
}
