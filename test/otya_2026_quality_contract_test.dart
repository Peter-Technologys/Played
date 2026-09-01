import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('Otya keeps the modern Material 3 and adaptive foundation', () {
    final theme = read('lib/app/theme/app_theme.dart');
    final dimensions = read('lib/app/theme/app_dimensions.dart');
    final router = read('lib/app/router.dart');

    expect(theme, contains('useMaterial3: true'));
    expect(theme, contains('PredictiveBackPageTransitionsBuilder'));
    expect(theme, contains('NavigationBarThemeData'));
    expect(theme, contains('NavigationRailThemeData'));
    expect(dimensions, contains('minimumTouchTarget = 48'));
    expect(dimensions, contains('mediumMin = 600'));
    expect(dimensions, contains('expandedMin = 840'));
    expect(router, contains('NavigationBar('));
  });

  test('Android production posture keeps scoped permissions and modern target', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final gradle = read('android/app/build.gradle');

    expect(gradle, contains('targetSdk = 36'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
    expect(manifest, contains('android:resizeableActivity="true"'));
    expect(manifest, isNot(contains('android.permission.MANAGE_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('android.permission.REQUEST_INSTALL_PACKAGES')));
  });

  test('PeterSmart Link internet traffic remains HTTPS-only at Android policy', () {
    final network = read(
      'android/app/src/main/res/xml/network_security_config.xml',
    );

    expect(
      network,
      contains('<domain-config cleartextTrafficPermitted="false">'),
    );
    expect(network, contains('petersmartlink.com'));
  });

  test('release terminology keeps coded, tested, built and released distinct', () {
    final standard = read('docs/OTYA_2026_PLUS_PRODUCT_STANDARD.md');

    expect(standard, contains('**Coded**'));
    expect(standard, contains('**CI/test passed**'));
    expect(standard, contains('**Built**'));
    expect(standard, contains('**Physical-device tested**'));
    expect(standard, contains('**Deployed/live**'));
    expect(standard, contains('**Released**'));
    expect(
      standard,
      contains('A green CI run does not imply physical-device acceptance'),
    );
  });

  test('the product standard protects offline use and internal boundaries', () {
    final standard = read('docs/OTYA_2026_PLUS_PRODUCT_STANDARD.md');

    expect(
      standard,
      contains('User work is never blocked by optional cloud features'),
    );
    expect(standard, contains('Fail soft for optional services; fail closed for security'));
    expect(standard, contains('One public assistant identity: Next'));
    expect(
      standard,
      contains('AI model names/providers'),
    );
  });
}
