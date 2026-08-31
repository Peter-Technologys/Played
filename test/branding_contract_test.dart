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

    // Otya product identity is the blue media O. The blue/red/yellow three-ball
    // triangle is reserved for Next and must not leak into the launcher mark.
    expect(foreground, contains('#FF68A6FF'));
    expect(foreground, contains('#FF2979FF'));
    expect(foreground, contains('#FF1767E8'));
    expect(foreground, isNot(contains('#FFFF3B30')));
    expect(foreground, isNot(contains('#FFFFD60A')));
    expect(foreground, contains('android:fillType="evenOdd"'));
    expect(foreground, contains('M248,216 L358,256 L248,296 Z'));
  });
}
