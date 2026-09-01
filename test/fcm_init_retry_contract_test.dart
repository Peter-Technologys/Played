import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/core/services/fcm_service.dart').readAsStringSync();

  test('FCM does not mark transient Firebase startup failure initialized', () {
    expect(source, contains('Future<void>? _initInFlight;'));
    expect(source, contains('bool _listenersAttached = false;'));
    expect(source, contains('final existing = _initInFlight;'));
    expect(source, contains('if (existing != null) return existing;'));
    expect(
      source.indexOf(
        'if (!await FirebasePlatformService.instance.ensureInitialized()) return;',
      ),
      lessThan(source.indexOf('_initialized = true;', source.indexOf('Future<void> _initOnce()'))),
      reason: 'A transient Firebase init failure must remain retryable.',
    );
  });

  test('FCM stream listeners attach at most once across retries', () {
    expect(source, contains('if (!_listenersAttached) {'));
    expect(source, contains('FirebaseMessaging.onMessage.listen('));
    expect(source, contains('FirebaseMessaging.onMessageOpenedApp.listen('));
    expect(source, contains('messaging.onTokenRefresh.listen('));
    expect(source, contains('_listenersAttached = true;'));
  });

  test('token sync failure does not tear down initialized FCM transport', () {
    final initialized = source.indexOf('_initialized = true;', source.indexOf('if (!_listenersAttached)'));
    final getToken = source.indexOf('final token = await messaging.getToken();');
    expect(initialized, greaterThanOrEqualTo(0));
    expect(getToken, greaterThan(initialized));
    expect(source, contains('initial token sync failed (non-fatal)'));
  });
}
