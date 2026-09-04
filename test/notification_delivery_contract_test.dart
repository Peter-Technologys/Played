import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary notification channels exist before background delivery', () {
    final source = File(
      'lib/core/services/shared_notification_plugin.dart',
    ).readAsStringSync();

    expect(source, contains('createNotificationChannel'));
    expect(source, contains("'otya_updates'"));
    expect(source, contains("'otya_announcements'"));
    expect(source, contains('getNotificationAppLaunchDetails'));
    expect(source, contains('didNotificationLaunchApp'));
  });

  test('existing installs receive the Android notification permission flow', () {
    final source =
        File('lib/core/services/fcm_service.dart').readAsStringSync();

    expect(source, contains('getNotificationSettings'));
    expect(source, contains('AuthorizationStatus.notDetermined'));
    expect(source, contains('messaging.requestPermission'));
  });

  test('remote notification links are limited to official HTTPS hosts', () {
    final fcm = File('lib/core/services/fcm_service.dart').readAsStringSync();
    final push = File(
      'lib/core/services/push_notification_service.dart',
    ).readAsStringSync();

    expect(fcm, contains("uri.scheme != 'https'"));
    expect(fcm, isNot(contains("{'https', 'http'}")));
    expect(push, contains("host.endsWith('.\$_officialHost')"));
    expect(push, contains('blocked untrusted notification URL'));
  });
}
