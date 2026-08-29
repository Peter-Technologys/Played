import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('online services stay outside the pre-first-frame startup path', () {
    final source = File('lib/app/app.dart').readAsStringSync();

    final initStart = source.indexOf('void initState()');
    final firstFrame = source.indexOf('SchedulerBinding.instance.addPostFrameCallback', initStart);

    expect(initStart, greaterThanOrEqualTo(0));
    expect(firstFrame, greaterThan(initStart));

    final beforeFirstFrame = source.substring(initStart, firstFrame);

    // These services may exist in the app, but they must never be started in
    // the critical pre-first-frame section. A phone in airplane mode must still
    // reach the OTYA UI.
    expect(beforeFirstFrame, isNot(contains('RemoteControlService.instance.init')));
    expect(beforeFirstFrame, isNot(contains('refreshSeasonalTheme')));
    expect(beforeFirstFrame, isNot(contains('FcmService.instance.init')));
    expect(beforeFirstFrame, isNot(contains('UpdateService.instance')));
    expect(beforeFirstFrame, isNot(contains('AuthService.instance')));
    expect(beforeFirstFrame, isNot(contains('http.')));
  });

  test('OTYA startup keeps local playback independent of Firebase config', () {
    final source = File('lib/core/services/fcm_service.dart').readAsStringSync();

    // Missing Firebase configuration must disable remote push instead of
    // throwing or blocking application startup.
    expect(source, contains('if (!OtyaFirebaseConfig.configured)'));
    expect(source, contains("Disabled: Firebase build configuration is incomplete"));
    expect(source, contains('non-fatal'));
  });
}
