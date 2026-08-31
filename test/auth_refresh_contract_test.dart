import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expired access tokens use one in-flight refresh request', () {
    final source =
        File('lib/core/services/auth_service.dart').readAsStringSync();

    expect(source, contains('Future<String?>? _refreshInFlight;'));
    expect(source, contains('final existingRefresh = _refreshInFlight;'));
    expect(source, contains('if (existingRefresh != null) return existingRefresh;'));
    expect(source, contains('final refresh = _refreshAccessToken();'));
    expect(source, contains('_refreshInFlight = refresh;'));
    expect(source, contains('identical(_refreshInFlight, refresh)'));
  });

  test('logout or account replacement invalidates an in-flight refresh', () {
    final source =
        File('lib/core/services/auth_service.dart').readAsStringSync();

    expect(source, contains('int _sessionGeneration = 0;'));
    expect(source, contains('_sessionGeneration++;'));
    expect(source, contains('final generation = _sessionGeneration;'));
    expect(
      source,
      contains(
        'generation != _sessionGeneration || _refreshToken != refreshToken',
      ),
    );
    expect(
      source.indexOf('generation != _sessionGeneration'),
      lessThan(source.indexOf("if (res.statusCode == 200)")),
      reason: 'A stale refresh response must be rejected before it can persist a new access token.',
    );
  });
}
