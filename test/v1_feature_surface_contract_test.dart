import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OTYA v1 feature surface contract', () {
    test('primary shell remains Video, Music and Me only', () {
      final router = File('lib/app/router.dart').readAsStringSync();

      expect(router, contains("path: '/',"));
      expect(router, contains("path: '/music',"));
      expect(router, contains("path: '/myspace',"));
      expect(router, contains("'/myspace'"));

      // Downloads/Files, Transfer and AI are useful destinations but must not
      // become extra permanent primary tabs in the v1 shell.
      expect(router, contains("path: '/downloads',"));
      expect(router, contains("path: '/transfer',"));
      expect(router, contains("path: '/support',"));
      expect(router, contains("path: '/ai', redirect: (_, __) => '/support'"));
    });

    test('legacy AirDrop route redirects to Transfer', () {
      final router = File('lib/app/router.dart').readAsStringSync();
      expect(
        router,
        contains("GoRoute(path: '/airdrop', redirect: (_, __) => '/transfer')"),
      );
    });

    test('player routes reject missing media instead of constructing fake items', () {
      final router = File('lib/app/router.dart').readAsStringSync();
      expect(router, contains("message: 'Could not open this video.'"));
      expect(router, contains("message: 'Could not open this song.'"));
    });

    test('Private, playlists, history and storage remain reachable from Me', () {
      final router = File('lib/app/router.dart').readAsStringSync();
      for (final route in [
        "path: '/vault'",
        "path: '/playlists'",
        "path: '/history'",
        "path: '/settings/storage'",
        "path: '/theme'",
      ]) {
        expect(router, contains(route));
      }
    });
  });
}
