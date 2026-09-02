import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final auth = File('lib/core/services/auth_service.dart').readAsStringSync();
  final account = File('lib/features/profile/account_screen.dart').readAsStringSync();
  final linking = File('lib/core/services/account_link_service.dart').readAsStringSync();
  final google = File('lib/core/services/google_account_service.dart').readAsStringSync();

  test('provider-only users keep a public Otya ID without requiring email', () {
    expect(auth, contains('final String? otyaId;'));
    expect(auth, contains("json['otya_id']"));
    expect(auth, contains("const _kPublicId = 'otya_public_id';"));
    expect(auth, contains('bool get hasEmail'));
    expect(auth, contains('String? get otyaPublicId'));
  });

  test('Android account can add email and opens user-scoped Otya Space', () {
    expect(account, contains('AccountLinkService.instance.addPrimaryEmail'));
    expect(account, contains("title: 'Add email'"));
    expect(account, contains("title: 'Sign-in methods'"));
    expect(account, contains('https://space.petersmartlink.com/u/'));
    expect(account, contains("'sessions' => 'devices'"));
    expect(account, contains("'connected' => 'providers'"));
  });

  test('identity linking stays separate from Google Drive permission', () {
    expect(linking, contains("Uri.parse('\$_kAuthBase/google/link')"));
    expect(linking, contains('addPrimaryEmail'));
    expect(google, isNot(contains('drive_access_token')));
    expect(auth, isNot(contains('drive_access_token')));
  });
}
