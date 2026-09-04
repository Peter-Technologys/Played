import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release publishing never rewrites v1.0.0 and requires tag to match main', () {
    final source = File('.github/workflows/release.yml').readAsStringSync();

    expect(source, isNot(contains('git tag -f')));
    expect(
      source,
      isNot(contains(r'git push --force origin "refs/tags/$RELEASE_TAG"')),
    );
    expect(source, isNot(contains('Align v1.0.0 tag to verified main')));
    expect(
      source,
      contains(r'TAG_SHA="$(git rev-list -n 1 "$RELEASE_TAG")"'),
    );
    expect(source, contains(r'test "$TAG_SHA" = "$MAIN_SHA"'));
    expect(
      source,
      contains('The workflow will not move tags.'),
    );
  });
}
