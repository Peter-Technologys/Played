import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/settings/presentation/settings_detail_screen.dart',
  ).readAsStringSync();

  test('Settings uses outcome-based hierarchy and canonical Next naming', () {
    expect(source, contains("'Look & feel'"));
    expect(source, contains("'Playback'"));
    expect(source, contains("'Privacy & device'"));
    expect(source, contains("'Product & support'"));
    expect(source, contains("title: 'Next'"));
    expect(source, isNot(contains("title: 'Ask OTYA'")));
  });

  test('Settings keeps real runtime controls reachable', () {
    for (final route in [
      "context.push('/theme')",
      "context.push('/vault')",
      "context.push('/settings/storage')",
      "context.push('/support')",
      "context.push('/privacy')",
      "context.push('/about')",
    ]) {
      expect(source, contains(route));
    }
    expect(source, contains('UpdateDialog.checkAndShow'));
    expect(source, contains('NotificationService.instance.requestPermission'));
  });
}
