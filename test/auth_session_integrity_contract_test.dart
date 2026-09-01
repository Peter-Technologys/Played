import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful auth responses require a complete session before persist', () {
    final source =
        File('lib/core/services/auth_service.dart').readAsStringSync();

    expect(source, contains("final accessTokenValue = data['access_token'];"));
    expect(source, contains("final refreshTokenValue = data['refresh_token'];"));
    expect(source, contains("final userValue = data['user'];"));
    expect(source, contains('accessTokenValue.trim().isEmpty'));
    expect(source, contains('refreshTokenValue.trim().isEmpty'));
    expect(source, contains('userValue is! Map<String, dynamic>'));
    expect(source, contains('user.id.trim().isEmpty'));
    expect(source, contains('user.email.trim().isEmpty'));

    final validationIndex = source.indexOf('accessTokenValue.trim().isEmpty');
    final persistIndex = source.indexOf(
      'await _persist(',
      source.indexOf('Future<AuthResult> _handleAuthResponse'),
    );
    expect(validationIndex, greaterThanOrEqualTo(0));
    expect(persistIndex, greaterThan(validationIndex));
  });

  test('incomplete success responses are converted to auth failures', () {
    final source =
        File('lib/core/services/auth_service.dart').readAsStringSync();

    expect(
      source,
      contains(
        'Authentication service returned incomplete session data. Please try again.',
      ),
    );
    expect(
      source,
      contains('return const AuthResult(\n            ok: false,'),
    );
  });
}
