import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/core/services/auth_service.dart').readAsStringSync();

  test('successful auth requires complete tokens and a user before persist', () {
    expect(source, contains("final accessTokenValue = data['access_token'];"));
    expect(source, contains("final refreshTokenValue = data['refresh_token'];"));
    expect(source, contains("final userValue = data['user'];"));
    expect(source, contains('accessTokenValue.trim().isEmpty'));
    expect(source, contains('refreshTokenValue.trim().isEmpty'));
    expect(source, contains('userValue is! Map<String, dynamic>'));
    expect(source, contains('user.id.trim().isEmpty'));

    final validationIndex = source.indexOf('accessTokenValue.trim().isEmpty');
    final persistIndex = source.indexOf(
      'await _persist(',
      source.indexOf('Future<AuthResult> _handleAuthResponse'),
    );
    expect(validationIndex, greaterThanOrEqualTo(0));
    expect(persistIndex, greaterThan(validationIndex));
  });

  test('provider-only accounts do not require an email address', () {
    expect(source, contains('final String? email;'));
    expect(source, contains('bool get hasEmail'));
    expect(
      source,
      isNot(contains('user.email.trim().isEmpty')),
      reason: 'Telegram-first accounts may legitimately have no primary email.',
    );
  });
}
