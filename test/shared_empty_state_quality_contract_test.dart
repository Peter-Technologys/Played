import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared empty state follows theme, accessibility and motion policy', () {
    final source = File(
      'lib/shared/widgets/empty_state.dart',
    ).readAsStringSync();

    expect(source, contains('Theme.of(context)'));
    expect(source, contains('theme.colorScheme'));
    expect(source, contains('theme.textTheme'));
    expect(source, contains('MediaQuery.disableAnimationsOf(context)'));
    expect(source, contains('Semantics('));
    expect(source, contains('SingleChildScrollView('));
    expect(source, contains('maxWidth: 420'));
    expect(source, contains('AppDimensions.motionStandard'));
    expect(source, isNot(contains('.repeat(')));
    expect(source, isNot(contains('AppColors.textPrimary')));
    expect(source, isNot(contains('AppColors.textSecondary')));
  });
}
