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

  test('Next screen paints incremental deltas instead of waiting for completion', () {
    expect(screen, contains('await for (final event in _service.askStream('));
    expect(screen, contains('answer += event.delta!'));
    expect(screen, contains("'Responding…'"));
    expect(screen, contains('OtyaThinkingMark'));
    expect(screen, contains('Ask Otya Support'));
  });
}
