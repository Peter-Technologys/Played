import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/core/services/otya_support_service.dart').readAsStringSync();

  test('Next client opts into SSE without removing JSON compatibility', () {
    expect(source, contains("headers['Accept'] = 'text/event-stream'"));
    expect(source, contains("contentType.contains('text/event-stream')"));
    expect(source, contains("data['answer']"));
    expect(source, contains('OtyaSupportStreamEvent.delta('));
    expect(source, contains('OtyaSupportStreamEvent.done('));
    expect(source, contains('Future<OtyaSupportReply> ask('));
  });

  test('Next streamed client has bounded connection and response waits', () {
    expect(source, contains('Duration(seconds: 12)'));
    expect(source, contains('Duration(seconds: 35)'));
    expect(source, contains('.timeout(_connectTimeout)'));
    expect(source, contains('.timeout(_timeout)'));
  });

  test('Next streamed client recognizes structured SSE lifecycle events', () {
    expect(source, contains("type == 'delta'"));
    expect(source, contains("type == 'error'"));
    expect(source, contains("type == 'done'"));
    expect(source, contains("line.startsWith('data:')"));
    expect(source, contains("payload == '[DONE]'"));
  });
}
