import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed direct-install APKs can only be built from current main', () {
    final source =
        File('.github/workflows/release-apk.yml').readAsStringSync();

    expect(source, contains('Verify direct-install build authority'));
    expect(
      source,
      contains(r'''test "$REQUESTED_REF" = 'refs/heads/main' '''),
    );
    expect(source, contains('Checkout exact current main'));
    expect(source, contains('ref: refs/heads/main'));
    expect(source, contains('Verify checkout is current main'));
    expect(
      source,
      contains('git fetch origin refs/heads/main:refs/remotes/origin/main --force'),
    );
    expect(source, contains(r'test "$HEAD_SHA" = "$MAIN_SHA"'));
  });
}
