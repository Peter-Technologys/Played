import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful empty scans clear stale library and duplicate state', () {
    final source = File(
      'lib/features/my_space/presentation/providers/my_space_provider.dart',
    ).readAsStringSync();

    expect(source, contains('state = AsyncData(fresh);'));
    expect(source, contains('unawaited(_detectDuplicates(fresh));'));
    expect(
      source,
      isNot(contains('if (fresh.isNotEmpty || currentItems.isEmpty)')),
    );
  });
}
