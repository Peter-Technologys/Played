import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smart Search stays local and has no consumer AI fallback', () {
    final search =
        File('lib/features/search/smart_search_sheet.dart').readAsStringSync();

    expect(search, isNot(contains('otya_support_service.dart')));
    expect(search, isNot(contains('OtyaSupportService'));
    expect(search, isNot(contains('_askAi')));
    expect(search, isNot(contains("_SectionLabel('Next'")));
    expect(search, isNot(contains('Optional online help'));
    expect(search, contains("'Send files'"));
    expect(search, contains('Open Me → Send.'));
    expect(search, contains('Search stays local'));
    expect(search, contains("'No local matches'"));
  });

  test('Privacy copy matches local Search and connected Together boundaries', () {
    final privacy = File(
      'lib/features/settings/presentation/privacy_policy_screen.dart',
    ).readAsStringSync();

    expect(privacy, contains('Core playback and Smart Search are offline-first'));
    expect(privacy, contains('An Otya account is optional for local playback, Smart Search'));
    expect(privacy, contains('and nearby Send. Google Sign-In'));
    expect(privacy, contains('The Otya Together control plane does not store'));
    expect(privacy, isNot(contains('Messages you send to Next')));
    expect(privacy, isNot(contains('Transfer sends supported files')));
  });

  test('Together end state uses the canonical Otya name', () {
    final together = File(
      'lib/features/together/presentation/nearby_together_live_surface.dart',
    ).readAsStringSync();

    expect(together, contains('Your normal Otya playback remains available.'));
    expect(together, isNot(contains('Your normal OTYA playback')));
  });
}
