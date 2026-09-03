import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('App Lock requires device authentication before persisting enabled', () {
    final source = File(
      'lib/features/settings/presentation/settings_detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import 'package:local_auth/local_auth.dart';"));
    expect(
      source,
      contains('onChanged: (enabled) => _setAppLock(context, notifier, enabled),'),
    );
    expect(source, contains('final supported = await auth.isDeviceSupported();'));
    expect(source, contains('final verified = await auth.authenticate('));
    expect(source, contains('if (verified) {\n        notifier.setAppLock(true);'));
  });

  test('disabling App Lock remains immediate and needs no authentication', () {
    final source = File(
      'lib/features/settings/presentation/settings_detail_screen.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('static Future<void> _setAppLock(');
    final nextMethod = source.indexOf('static Future<void> _chooseWallpaper', methodStart);
    final body = source.substring(methodStart, nextMethod);

    expect(
      body,
      contains('if (!enabled) {\n      notifier.setAppLock(false);\n      return;\n    }'),
    );
    expect(
      body.indexOf('notifier.setAppLock(false);'),
      lessThan(body.indexOf('final auth = LocalAuthentication();')),
    );
  });
}
