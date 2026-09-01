import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('What’s New has intentional loading, failure and empty states', () {
    final source = File(
      'lib/features/profile/whats_new_screen.dart',
    ).readAsStringSync();

    expect(source, contains('AnimatedSwitcher('));
    expect(source, contains('Semantics('));
    expect(source, contains("label: 'Loading what’s new'"));
    expect(source, contains('EmptyState('));
    expect(source, contains('Couldn’t load what’s new'));
    expect(source, contains('You’re up to date'));
    expect(source, contains('onPressed: _load'));
    expect(source, contains('Theme.of(context)'));
    expect(source, contains('SelectionArea('));
    expect(source, isNot(contains('AppColors.textSecondary')));
    expect(source, isNot(contains('_errorDescription')));
  });
}
