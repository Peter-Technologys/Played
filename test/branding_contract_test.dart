import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher preserves the original OTYA folded identity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final foreground = File(
      'android/app/src/main/res/drawable/otya_launcher_foreground.xml',
    ).readAsStringSync();
    final logo = File('lib/shared/widgets/otya_logo_v2.dart').readAsStringSync();

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

    // Product identity: preserve the recognizable folded O geometry and the
    // original blue/red/yellow detail. Modernization may refine rendering but
    // must not replace the symbol with a generic ring/play mark.
    expect(foreground, contains('M160,98 L138,117 L116,146'));
    expect(foreground, contains('M180,142 L159,147 L139,157'));
    expect(foreground, contains('M405,164 L410,190 L408,224'));
    expect(foreground, contains('#FF2979FF'));
    expect(foreground, contains('#FFFF3B30'));
    expect(foreground, contains('#FFFFD60A'));
    expect(foreground, isNot(contains('android:fillType="evenOdd"')));
    expect(foreground, isNot(contains('M248,216 L358,256 L248,296 Z')));

    expect(logo, contains('class _OtyaPainter extends CustomPainter'));
    expect(logo, contains('static Path _top()'));
    expect(logo, contains('static Path _left()'));
    expect(logo, contains('static Path _right()'));
    expect(logo, contains('Color(0xFF2979FF)'));
    expect(logo, contains('Color(0xFFFF3B30)'));
    expect(logo, contains('Color(0xFFFFD60A)'));
    expect(logo, isNot(contains('simple modern media O')));
  });
}
