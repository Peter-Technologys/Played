import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher and Flutter UI use the current Otya identity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final foreground = File(
      'android/app/src/main/res/drawable/otya_launcher_foreground.xml',
    ).readAsStringSync();
    final monochrome = File(
      'android/app/src/main/res/drawable/otya_launcher_monochrome.xml',
    ).readAsStringSync();
    final logo = File('lib/shared/widgets/otya_logo_v2.dart')
        .readAsStringSync();
    final colors = File('lib/app/theme/app_colors.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher"'));
    expect(
      manifest,
      isNot(contains('android:icon="@drawable/otya_launcher_icon"')),
      reason: 'Modern Android launchers must receive the adaptive icon.',
    );

    expect(adaptive, contains('@drawable/otya_launcher_foreground'));
    expect(adaptive, contains('@color/otya_launcher_background'));
    expect(foreground, contains('@mipmap/ic_launcher_foreground'));
    expect(monochrome, contains('@mipmap/ic_launcher_monochrome'));

    expect(logo, contains("'assets/branding/otya_mark_current.png'"));
    expect(logo, contains('Image.asset('));
    expect(pubspec, contains('- assets/branding/'));
    expect(colors, contains('brandCyan = Color(0xFF27E8FF)'));
    expect(colors, contains('brandBlue = Color(0xFF126BFF)'));
    expect(colors, contains('colors: [brandCyan, brandBlue, brandDeepBlue]'));

    expect(File('assets/branding/otya_mark_current.png').existsSync(), isTrue);
    expect(File('assets/branding/otya_app_icon.webp').existsSync(), isTrue);
    expect(File('assets/icons/play_store_512.png').existsSync(), isTrue);

    expect(
      foreground,
      isNot(contains('M160,98 L138,117 L116,146')),
      reason: 'The retired folded white/grey mark must not return to launcher.',
    );
  });
}