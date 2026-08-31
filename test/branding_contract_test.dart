import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher uses the current Otya adaptive vector identity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final foreground = File(
      'android/app/src/main/res/drawable/otya_launcher_foreground.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher"'));
    expect(
      manifest,
      isNot(contains('android:icon="@drawable/otya_launcher_icon"')),
      reason: 'Modern Android launchers must receive the adaptive icon so the '
          'system does not double-mask a precomposed badge.',
    );

    expect(adaptive, contains('@drawable/otya_launcher_foreground'));
    expect(adaptive, contains('@color/otya_launcher_background'));

    // Blue, red and yellow are the three Otya identity balls.
    expect(foreground, contains('#FF2979FF'));
    expect(foreground, contains('#FFFF3B30'));
    expect(foreground, contains('#FFFFD60A'));
    expect(foreground, contains('android:scaleX="0.90"'));
    expect(foreground, contains('android:scaleY="0.90"'));
  });
}
