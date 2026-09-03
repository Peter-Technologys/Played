import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings snapshots are saved sequentially', () {
    final source =
        File('lib/features/settings/settings_provider.dart').readAsStringSync();

    expect(source, contains('Future<void> _saveChain = Future<void>.value();'));
    expect(source, contains('_saveChain = _saveChain'));
    expect(source, contains('.then((_) => s.save())'));
    expect(source, isNot(contains('s.save().ignore();')));
  });
}
