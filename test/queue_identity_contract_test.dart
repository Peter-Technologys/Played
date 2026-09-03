import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removing queue items preserves the active track by identity', () {
    final queue = File('lib/features/player/presentation/queue_screen.dart')
        .readAsStringSync();

    expect(queue, contains('if (index < 0 || index >= state.items.length) return;'));
    expect(queue, contains('final currentId = state.current?.id;'));
    expect(queue, contains('updated.indexWhere((item) => item.id == currentId)'));
    expect(queue, contains('final preservedIndex'));
    expect(queue, contains('index.clamp(0, updated.length - 1)'));
  });
}
