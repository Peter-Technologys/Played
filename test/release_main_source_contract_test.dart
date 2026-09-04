import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production release must use current main and an already-aligned tag', () {
    final source = File('.github/workflows/release.yml').readAsStringSync();

    expect(
      source,
      contains('git fetch origin refs/heads/main:refs/remotes/origin/main'),
    );
    expect(
      source,
      contains(r'MAIN_SHA="$(git rev-parse refs/remotes/origin/main)"'),
    );
    expect(
      source,
      contains(r'TAG_SHA="$(git rev-list -n 1 "$RELEASE_TAG")"'),
    );
    expect(source, contains(r'test "$HEAD_SHA" = "$MAIN_SHA" || {'));
    expect(source, contains(r'test "$TAG_SHA" = "$MAIN_SHA" || {'));
    expect(source, isNot(contains('git tag -f')));
    expect(source, isNot(contains('git push --force origin')));

    final headGuard = source.indexOf(r'test "$HEAD_SHA" = "$MAIN_SHA" || {');
    final tagGuard = source.indexOf(r'test "$TAG_SHA" = "$MAIN_SHA" || {');
    final build = source.indexOf('- name: Build release artifacts');
    final publish = source.indexOf('- name: Publish Otya APKs');
    expect(headGuard, greaterThanOrEqualTo(0));
    expect(tagGuard, greaterThanOrEqualTo(0));
    expect(headGuard, lessThan(build));
    expect(tagGuard, lessThan(build));
    expect(headGuard, lessThan(publish));
    expect(tagGuard, lessThan(publish));
  });

  test('manual production release still checks out main', () {
    final source = File('.github/workflows/release.yml').readAsStringSync();
    expect(
      source,
      contains(
        r"ref: ${{ github.event_name == 'workflow_dispatch' && 'refs/heads/main' || github.ref }}",
      ),
    );
  });
}
