import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logout clears the local session before remote revocation', () {
    final source = File('lib/core/services/auth_service.dart').readAsStringSync();
    final logoutStart = source.indexOf('Future<void> logout() async');
    final revokeStart = source.indexOf('Future<void> _revokeRefreshToken');

    expect(logoutStart, greaterThanOrEqualTo(0));
    expect(revokeStart, greaterThan(logoutStart));

    final logoutBody = source.substring(logoutStart, revokeStart);
    final clear = logoutBody.indexOf('await _clearPersisted();');
    final revoke = logoutBody.indexOf('unawaited(_revokeRefreshToken(refreshToken));');

    expect(clear, greaterThanOrEqualTo(0));
    expect(revoke, greaterThan(clear));
    expect(source, contains("import 'dart:async';"));
    expect(
      logoutBody,
      isNot(contains("await _client\n            .post(\n              Uri.parse('\$_kAuthBase/logout')")),
    );
  });

  test('remote logout still uses the captured refresh token', () {
    final source = File('lib/core/services/auth_service.dart').readAsStringSync();
    expect(source, contains('final refreshToken = _refreshToken;'));
    expect(source, contains("body: jsonEncode({'refresh_token': refreshToken})"));
    expect(source, contains("Uri.parse('\$_kAuthBase/logout')"));
  });
}
