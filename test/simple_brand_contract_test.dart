import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release files use the simple Otya brand', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final publisher = File('scripts/publish_r2.sh').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:label="Otya"'));
    expect(workflow, contains('Otya-arm64.apk'));
    expect(workflow, contains('Otya-arm32.apk'));
    expect(workflow, contains('Otya.aab'));
    expect(publisher, contains('releases/\${RAW_TAG}/Otya-arm64.apk'));
    expect(publisher, contains('releases/\${RAW_TAG}/Otya-arm32.apk'));

    expect(workflow, isNot(contains('OTYA Player')));
    expect(publisher, isNot(contains('OTYA-Player-')));
    expect(publisher, isNot(contains('OtyaPlayer-arm64.apk')));
    expect(publisher, isNot(contains('OtyaPlayer-arm32.apk')));
  });
}
