import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public app version remains 1.0.0 with a positive internal build', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(pubspec);

    expect(match, isNotNull);
    final version = match!.group(1)!;
    expect(version, matches(RegExp(r'^1\.0\.0\+[1-9][0-9]*$')));
  });

  test('normal and direct-release CI require zero analyzer issues', () {
    final testWorkflow =
        File('.github/workflows/test-apk.yml').readAsStringSync();
    final directRelease =
        File('.github/workflows/release-apk.yml').readAsStringSync();

    expect(testWorkflow, contains('run: flutter analyze'));
    expect(testWorkflow, isNot(contains('--no-fatal-infos')));
    expect(directRelease, contains('run: flutter analyze'));
    expect(directRelease, isNot(contains('--no-fatal-infos')));
    expect(testWorkflow, contains('actions/checkout@v6'));
    expect(directRelease, contains('actions/checkout@v6'));
  });

  test('direct release build enforces the v1.0.0 version identity', () {
    final directRelease =
        File('.github/workflows/release-apk.yml').readAsStringSync();

    expect(directRelease, contains('Verify v1.0.0 release identity'));
    expect(directRelease, contains(r'^1\.0\.0\+[1-9][0-9]*$'));
  });

  test('retired Online Music cannot return as a release dependency', () {
    final env = File('lib/core/config/environment.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(env, isNot(contains('onlineMusicUrl')));
    expect(env, isNot(contains('JAMENDO')));
    expect(env, isNot(contains('SPOTIFY_CLIENT_ID')));
    expect(pubspec.toLowerCase(), isNot(contains('spotify')));
    expect(pubspec.toLowerCase(), isNot(contains('jamendo')));
  });
}
