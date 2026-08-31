import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter binding initialization and runApp stay inside one guarded zone', () {
    final main = File('lib/main.dart').readAsStringSync();

    final zoneIndex = main.indexOf('runZonedGuarded(() async {');
    final bindingIndex = main.indexOf('WidgetsFlutterBinding.ensureInitialized();');
    final runAppIndex = main.indexOf('runApp(');

    expect(zoneIndex, greaterThanOrEqualTo(0));
    expect(bindingIndex, greaterThan(zoneIndex));
    expect(runAppIndex, greaterThan(bindingIndex));
    expect(
      main.substring(0, zoneIndex),
      isNot(contains('WidgetsFlutterBinding.ensureInitialized();')),
      reason: 'Initializing the Flutter binding outside the zone and calling '
          'runApp inside it causes a startup Zone mismatch.',
    );
    expect(
      main,
      isNot(contains('_showCrashOverlay')),
      reason: 'Error handling must not recursively replace the root app with '
          'another runApp call during startup failures.',
    );
  });

  test('Android launcher uses the adaptive mipmap instead of a legacy drawable', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final foreground = File(
      'android/app/src/main/res/drawable/otya_launcher_foreground.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher"'));
    expect(manifest, isNot(contains('android:icon="@drawable/otya_launcher_icon"')));
    expect(adaptive, contains('@drawable/otya_launcher_foreground'));
    expect(adaptive, contains('@color/otya_launcher_background'));
    expect(foreground, contains('android:viewportWidth="512"'));
    expect(foreground, contains('android:viewportHeight="512"'));
    expect(foreground, contains('android:fillType="evenOdd"'));
    expect(foreground, contains('#FF2979FF'));
  });
}
