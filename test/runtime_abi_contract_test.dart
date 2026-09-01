import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production architecture is detected from the running Dart VM', () {
    final source =
        File('lib/core/config/environment.dart').readAsStringSync();

    expect(source, contains("import 'dart:ffi';"));
    expect(
      source,
      contains("String.fromEnvironment('APP_ARCH', defaultValue: '')"),
    );
    expect(source, contains('final abi = Abi.current();'));
    expect(source, contains("if (abi == Abi.androidArm) return 'arm32';"));
    expect(source, contains("if (abi == Abi.androidArm64) return 'arm64';"));
    expect(
      source,
      isNot(
        contains("String.fromEnvironment('APP_ARCH', defaultValue: 'arm64')"),
      ),
      reason:
          'A shared split-per-ABI build must not silently label every install arm64.',
    );
  });

  test('device registration uses the same canonical runtime ABI', () {
    final source =
        File('lib/core/services/device_service.dart').readAsStringSync();

    expect(source, contains("'arch': Environment.appArch"));
    expect(source, isNot(contains("String.fromEnvironment('APP_ARCH'")));
  });
}
