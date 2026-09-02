import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Telegram-first Otya accounts may have no email', () {
    final auth = File('lib/core/services/auth_service.dart').readAsStringSync();

    expect(auth, contains('final String? email;'));
    expect(auth, contains('this.email,'));
    expect(auth, contains("final rawEmail = json['email'];"));
    expect(auth, contains('rawEmail is String && rawEmail.trim().isNotEmpty'));
    expect(auth, isNot(contains("email: json['email'] as String")));
    expect(auth, contains('await prefs.remove(_kUserEmail);'));
  });

  test('basic Google identity does not send or require a Drive access token', () {
    final auth = File('lib/core/services/auth_service.dart').readAsStringSync();
    final google =
        File('lib/core/services/google_account_service.dart').readAsStringSync();

    expect(auth, contains('Future<AuthResult> loginWithGoogle(\n    String idToken, {'));
    expect(auth, isNot(contains('driveAccessToken')));
    expect(auth, isNot(contains("'drive_access_token'")));
    expect(google, contains('AuthService.instance.loginWithGoogle(\n              idToken,'));
    expect(google, isNot(contains("idToken,\n              '',")));
  });

  test('Google Drive remains an explicit lazy permission', () {
    final google =
        File('lib/core/services/google_account_service.dart').readAsStringSync();

    expect(google, contains("'email',"));
    expect(google, contains("'profile',"));
    expect(google, contains('requestScopes(const <String>['));
    expect(google, contains('_driveAppDataScope'));
    expect(google.indexOf('requestScopes(const <String>['),
        greaterThan(google.indexOf('Future<String?> _freshDriveToken()')));
  });

  test('existing Otya session links Google before signed-out create-or-login', () {
    final google =
        File('lib/core/services/google_account_service.dart').readAsStringSync();

    expect(google, contains('AuthService.instance.checkIsLoggedIn()'));
    expect(google, contains('AccountLinkService.instance.linkGoogle(idToken)'));
    expect(google, contains('AuthService.instance.loginWithGoogle('));
    expect(
      google.indexOf('AccountLinkService.instance.linkGoogle(idToken)'),
      lessThan(google.indexOf('AuthService.instance.loginWithGoogle(')),
    );
  });
}
