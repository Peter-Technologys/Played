import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tag-triggered production release must point to current main', () {
    final source = File('.github/workflows/release.yml').readAsStringSync();

    expect(
      source,
      contains(r'''if [ "${{ github.event_name }}" = "push" ]; then'''),
    );
    expect(
      source,
      contains('git fetch origin refs/heads/main:refs/remotes/origin/main'),
    );
    expect(
      source,
      contains(r'''MAIN_SHA="$(git rev-parse refs/remotes/origin/main)"'''),
    );
    expect(source, contains(r'''test "$HEAD_SHA" = "$MAIN_SHA" || {'''));

    final guard = source.indexOf(r'''test "$HEAD_SHA" = "$MAIN_SHA" || {''');
    final build = source.indexOf('- name: Build release artifacts');
    final publish = source.indexOf('- name: Publish Otya APKs');
    expect(guard, greaterThanOrEqualTo(0));
    expect(guard, lessThan(build));
    expect(guard, lessThan(publish));
  });

  test('manual production release still checks out main', () {
    final source = File('.github/workflows/release.yml').readAsStringSync();
    expect(
      source,
      contains(
        r'''ref: ${{ github.event_name == 'workflow_dispatch' && 'refs/heads/main' || github.ref }}''',
      ),
    );
  });
}
