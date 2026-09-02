import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File('lib/core/services/otya_support_service.dart').readAsStringSync();
  final screen = File('lib/features/ai/otya_support_screen_v3.dart').readAsStringSync();

  test('Next client opts into SSE without removing JSON compatibility', () {
    expect(service, contains("headers['Accept'] = 'text/event-stream'"));
    expect(service, contains("contentType.contains('text/event-stream')"));
    expect(service, contains("data['answer']"));
    expect(service, contains('OtyaSupportStreamEvent.delta('));
    expect(service, contains('OtyaSupportStreamEvent.done('));
    expect(service, contains('Future<OtyaSupportReply> ask('));
  });

  test('Next streamed client has bounded connection and response waits', () {
    expect(service, contains('Duration(seconds: 12)'));
    expect(service, contains('Duration(seconds: 35)'));
    expect(service, contains('.timeout(_connectTimeout)'));
    expect(service, contains('.timeout(_timeout)'));
  });

  test('Next starts auth and App Check preflight concurrently', () {
    expect(
      service,
      contains('final authTokenFuture = AuthService.instance.getValidToken();'),
    );
    expect(
      service,
      contains(
        'final appCheckTokenFuture =\n        FirebasePlatformService.instance.appCheckToken();',
      ),
    );

    final authStart = service.indexOf('final authTokenFuture =');
    final appCheckStart = service.indexOf('final appCheckTokenFuture =');
    final firstAwait = service.indexOf('final token = await authTokenFuture;');
    expect(authStart, greaterThanOrEqualTo(0));
    expect(appCheckStart, greaterThan(authStart));
    expect(firstAwait, greaterThan(appCheckStart));
    expect(
      service,
      isNot(contains('return FirebasePlatformService.instance.protectedHeaders(')),
      reason: 'App Check must not wait behind an auth refresh.',
    );
  });

  test('Next screen paints incremental deltas instead of waiting for completion', () {
    expect(screen, contains('await for (final event in _service.askStream('));
    expect(screen, contains('answer += event.delta!'));
    expect(screen, contains("'Responding…'"));
    expect(screen, contains('OtyaThinkingMark'));
    expect(screen, contains('Ask Otya Support'));
  });
}
