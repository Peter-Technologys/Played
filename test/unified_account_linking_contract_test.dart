import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google links to the current OTYA ID when a session already exists', () {
    final google =
        File('lib/core/services/google_account_service.dart').readAsStringSync();

    expect(google, contains('final hasOtyaSession = await AuthService.instance.checkIsLoggedIn();'));
    expect(google, contains('AccountLinkService.instance.linkGoogle(idToken)'));
    expect(google, contains('AuthService.instance.loginWithGoogle('));
    expect(
      google.indexOf('AccountLinkService.instance.linkGoogle(idToken)'),
      lessThan(google.indexOf('AuthService.instance.loginWithGoogle(')),
      reason: 'An existing OTYA session must choose provider linking before the signed-out Google create/login path.',
    );
  });

  test('provider linking is authenticated and targets the canonical auth routes', () {
    final linking =
        File('lib/core/services/account_link_service.dart').readAsStringSync();

    expect(linking, contains('AuthService.instance.getValidToken()'));
    expect(linking, contains("Uri.parse('\$_kAuthBase/google/link')"));
    expect(linking, contains("'Authorization': 'Bearer \$token'"));
    expect(linking, contains("Uri.parse('\$_kAuthBase/account')"));
    expect(linking, contains("body: jsonEncode({'email': normalized})"));
  });

  test('Drive permission remains separate from basic Google identity linking', () {
    final google =
        File('lib/core/services/google_account_service.dart').readAsStringSync();

    expect(google, contains("'email',"));
    expect(google, contains("'profile',"));
    expect(google, contains('requestScopes(const <String>['));
    expect(google, contains('_driveAppDataScope'));
  });
}
