import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android notification surfaces use the canonical OTYA brand', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final channels = File(
      'lib/core/services/shared_notification_plugin.dart',
    ).readAsStringSync();

    expect(
      mainSource,
      contains("androidNotificationChannelName: 'OTYA — Now Playing'"),
    );
    expect(channels, contains("'OTYA — Updates'"));
    expect(channels, contains("'OTYA — Announcements'"));
    expect(channels, contains("'OTYA Tools — Progress'"));
    expect(channels, contains("'OTYA Tools — Complete'"));
    expect(channels, contains("'OTYA Tools — Errors'"));
  });

  test('Together join keeps network details behind user-facing language', () {
    final source = File(
      'lib/features/together/presentation/nearby_together_join_sheet.dart',
    ).readAsStringSync();

    expect(source, contains("hintText: 'Paste the invite here'"));
    expect(source, contains('OTYA reuses what you already watched'));
    expect(source, contains('The video stays between your phones.'));
    expect(source, isNot(contains("hintText: 'ws://")));
    expect(source, isNot(contains('Reuse watched bytes')));
  });
}
