import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('online services stay outside the pre-first-frame startup path', () {
    final source = File('lib/app/app.dart').readAsStringSync();

    final initStart = source.indexOf('void initState()');
    final firstFrame = source.indexOf(
      'SchedulerBinding.instance.addPostFrameCallback',
      initStart,
    );

    expect(initStart, greaterThanOrEqualTo(0));
    expect(firstFrame, greaterThan(initStart));

    final beforeFirstFrame = source.substring(initStart, firstFrame);

    expect(
      beforeFirstFrame,
      isNot(contains('RemoteControlService.instance.init')),
    );
    expect(beforeFirstFrame, isNot(contains('refreshSeasonalTheme')));
    expect(beforeFirstFrame, isNot(contains('FcmService.instance.init')));
    expect(beforeFirstFrame, isNot(contains('UpdateService.instance')));
    expect(beforeFirstFrame, isNot(contains('AuthService.instance')));
    expect(beforeFirstFrame, isNot(contains('http.')));
    expect(beforeFirstFrame, isNot(contains('OnlineMusicService')));
    expect(beforeFirstFrame, isNot(contains('JAMENDO')));
  });

  test('startup hydrates App Lock before revealing router content', () {
    final source = File('lib/app/app.dart').readAsStringSync();
    final hydrate = source.indexOf(
      'ref.read(settingsProvider.notifier).hydrate(savedSettings)',
    );
    final reveal = source.indexOf('_checking = false', hydrate);

    expect(hydrate, greaterThanOrEqualTo(0));
    expect(reveal, greaterThan(hydrate));
    expect(source, contains('_hydrateStartupPrivacyAndOnboarding()'));
  });

  test('media-session playback does not request ordinary notification consent', () {
    final source = File(
      'lib/core/services/media_notification_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('NotificationService.instance.requestPermission')));
    expect(source, isNot(contains('existsSync()')));
  });

  test('OTYA startup keeps local playback independent of Firebase config', () {
    final source = File('lib/core/services/fcm_service.dart').readAsStringSync();

    expect(source, contains('if (!OtyaFirebaseConfig.configured)'));
    expect(
      source,
      contains('Disabled: Firebase build configuration is incomplete'),
    );
    expect(source, contains('non-fatal'));
  });

  test('global search remains local-first when online music is unavailable', () {
    final source =
        File('lib/features/search/smart_search_sheet.dart').readAsStringSync();

    expect(source, contains('_mediaMatches(library)'));
    expect(source, contains('_groupMatches(library)'));
    expect(source, contains('_playlistMatches(playlists)'));
    expect(source, contains("Timer(const Duration(milliseconds: 380)"));
    expect(source, contains('OnlineMusicService.instance'));
    expect(source, contains('Connectivity().checkConnectivity()'));
    expect(source, contains("_onlineTracks = const []"));
    expect(
      source,
      contains('Local songs, videos, albums, artists, folders and playlists appear instantly.'),
    );
  });

  test('online music failures do not replace local search with an error state', () {
    final source =
        File('lib/features/search/smart_search_sheet.dart').readAsStringSync();

    expect(source, isNot(contains("_onlineError")));
    expect(source, contains('catch (_)'));
    expect(source, contains('_onlineLoading = false'));
  });
}
