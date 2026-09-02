import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Telegram-first OTYA profiles may have no email and retain public OTYA ID', () {
    final auth = File('lib/core/services/auth_service.dart').readAsStringSync();

    expect(auth, contains('final String? otyaId;'));
    expect(auth, contains('final String? email;'));
    expect(auth, contains("otyaId: json['otya_id'] as String?"));
    expect(auth, contains("email: json['email'] as String?"));
    expect(auth, contains("const _kOtyaPublicId = 'otya_public_id';"));
    expect(auth, contains('await prefs.remove(_kUserEmail);'));
  });

  test('Account offers email linking and opens canonical OTYA Space routes', () {
    final account = File('lib/features/profile/account_screen.dart').readAsStringSync();

    expect(account, contains('AccountLinkService.instance.addPrimaryEmail(email)'));
    expect(account, contains("title: 'Add email'"));
    expect(account, contains('https://space.petersmartlink.com/u/$publicId/'));
    expect(account, isNot(contains('https://petersmartlink.com/account#')));
  });

  test('Google connection uses existing-session provider linking', () {
    final google = File('lib/core/services/google_account_service.dart').readAsStringSync();
    final linker = File('lib/core/services/account_link_service.dart').readAsStringSync();

    expect(google, contains('AccountLinkService.instance.linkGoogle(idToken)'));
    expect(linker, contains("Uri.parse('$_kAuthBase/google/link')"));
    expect(linker, contains("'Authorization': 'Bearer $token'"));
  });
}
