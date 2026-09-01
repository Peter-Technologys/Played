import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visible new chats request a fresh server conversation', () {
    final source = File('lib/core/services/otya_support_service.dart')
        .readAsStringSync();

    expect(source, contains('final startsVisibleConversation = safeHistory.isEmpty;'));
    expect(source, contains("if (startsVisibleConversation) 'new_chat': true"));
  });

  test('continued chats bind to the conversation id returned by Next', () {
    final source = File('lib/core/services/otya_support_service.dart')
        .readAsStringSync();

    expect(source, contains("conversationId: json['conversation_id']?.toString()"));
    expect(source, contains('_rememberConversation(event.conversationId);'));
    expect(source, contains("'conversation_id': _conversationId"));
  });
}
