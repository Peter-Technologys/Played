import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher uses the current OTYA vector identity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final launcher = File(
      'android/app/src/main/res/drawable/otya_launcher_icon.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:icon="@drawable/otya_launcher_icon"'));
    expect(manifest, contains('android:roundIcon="@drawable/otya_launcher_icon"'));
    expect(
      manifest,
      isNot(contains('android:icon="@mipmap/ic_launcher"')),
      reason: 'The old raster mipmap still contains the retired purple/play-note identity.',
    );

    // Blue, red and yellow are the three small OTYA AI/brand circles.
    expect(launcher, contains('#FF2979FF'));
    expect(launcher, contains('#FFFF3B30'));
    expect(launcher, contains('#FFFFD60A'));
    expect(launcher, contains('#FF080B12'));
  });
}
