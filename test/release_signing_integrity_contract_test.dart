import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direct-install release is manual and uses Android APK verification', () {
    final source =
        File('.github/workflows/release-apk.yml').readAsStringSync();

    expect(source, contains('workflow_dispatch:'));
    expect(source, isNot(contains('branches: [v1-rebuild]')));
    expect(source, contains('apksigner'));
    expect(source, contains('verify --verbose --print-certs'));
    expect(source, contains('certificate SHA-256 digest'));
    expect(
      source,
      contains(
        'release APK certificate does not match the configured Otya signing key',
      ),
    );
    expect(source, isNot(contains('keytool -printcert -jarfile "$APK"')));
  });

  test('production release verifies both APK signers before publication', () {
    final source = File('.github/workflows/release.yml').readAsStringSync();

    expect(source, contains('"$APKSIGNER" verify --verbose --print-certs "$ARM64"'));
    expect(source, contains('"$APKSIGNER" verify --verbose --print-certs "$ARM32"'));
    expect(source, contains('EXPECTED_SHA256'));
    expect(source, contains('ACTUAL_SHA256'));
    expect(
      source,
      contains(
        'release APK certificate does not match the configured Otya signing key',
      ),
    );
  });

  test('Play bundle signature is also verified against the Otya key', () {
    final source = File('.github/workflows/release.yml').readAsStringSync();

    expect(source, contains('jarsigner -verify "$AAB"'));
    expect(source, contains('keytool -printcert -jarfile "$AAB"'));
    expect(source, contains('AAB_SHA256'));
    expect(
      source,
      contains(
        'app bundle certificate does not match the configured Otya signing key',
      ),
    );
  });
}
