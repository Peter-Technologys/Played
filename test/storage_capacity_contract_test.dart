import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('storage analyzer uses df available space instead of fabricated capacity', () {
    final source = File(
      'lib/core/services/storage_analyzer_service.dart',
    ).readAsStringSync();

    expect(source, contains('final availableKb = int.tryParse(parts[3])'));
    expect(source, contains('final usedStorage = capacity.totalBytes - capacity.freeBytes;'));
    expect(source, contains('usedStorage - knownBytes'));
    expect(source, contains('capacityKnown: false'));
    expect(source, isNot(contains('64 * 1024 * 1024 * 1024')));
    expect(source, isNot(contains('totalBytes - videoBytes - audioBytes - cacheBytes')));
  });
}
