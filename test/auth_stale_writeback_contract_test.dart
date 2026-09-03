import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _method(String source, String start, String next) {
  final begin = source.indexOf(start);
  final end = source.indexOf(next, begin + start.length);
  expect(begin, greaterThanOrEqualTo(0), reason: 'Missing $start');
  expect(end, greaterThan(begin), reason: 'Missing boundary $next');
  return source.substring(begin, end);
}

void main() {
  test('authenticated write-backs reject responses from stale sessions', () {
    final source = File('lib/core/services/auth_service.dart').readAsStringSync();

    final getProfile = _method(
      source,
      'Future<UserProfile?> getProfile() async',
      'Future<void> updateProfile',
    );
    expect(getProfile, contains('final generation = _sessionGeneration;'));
    expect(getProfile, contains('if (generation != _sessionGeneration) return null;'));
    expect(
      getProfile.indexOf('if (generation != _sessionGeneration) return null;'),
      lessThan(getProfile.indexOf('await _persist(user: user);')),
    );

    final updateProfile = _method(
      source,
      'Future<void> updateProfile',
      'Future<bool> sendVerificationOtp',
    );
    expect(updateProfile, contains('final generation = _sessionGeneration;'));
    expect(updateProfile, contains('if (generation != _sessionGeneration) return;'));
    expect(
      updateProfile.lastIndexOf('if (generation != _sessionGeneration) return;'),
      lessThan(updateProfile.indexOf('await _persist(user: user);')),
    );

    final verifyOtp = _method(
      source,
      'Future<bool> verifyOtp(String otp) async',
      'Future<bool> forgotPassword',
    );
    expect(verifyOtp, contains('final generation = _sessionGeneration;'));
    expect(verifyOtp, contains('if (generation != _sessionGeneration) return false;'));
    expect(
      verifyOtp.lastIndexOf('if (generation != _sessionGeneration) return false;'),
      lessThan(verifyOtp.indexOf('await prefs.setBool(_kIsVerified, true);')),
    );
  });
}
