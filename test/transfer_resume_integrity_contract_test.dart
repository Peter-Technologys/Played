import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sender and receiver use the same 256-bit transfer token contract', () {
    final sender = File('lib/features/transfer/data/media_sender.dart')
        .readAsStringSync();
    final receiver = File('lib/features/transfer/data/media_receiver.dart')
        .readAsStringSync();

    expect(sender, contains('List.generate(\n      32,'));
    expect(receiver, contains("RegExp(r'^[a-f0-9]{64}\$')"));
  });

  test('a 416 response is accepted only for a bounded exact length match', () {
    final source = File('lib/features/transfer/data/media_receiver.dart')
        .readAsStringSync();

    expect(source, contains('_lengthFromUnsatisfiedRange(response)'));
    expect(source, contains('remoteLength != null'));
    expect(source, contains('remoteLength <= _maxTransferBytes'));
    expect(source, contains('existingBytes == remoteLength'));
    expect(source, contains("RegExp(r'^bytes \\*/(\\d+)\$')"));
  });

  test('invalid resume offsets discard suspect bytes and restart', () {
    final source = File('lib/features/transfer/data/media_receiver.dart')
        .readAsStringSync();

    expect(
      source,
      contains('if (await saveFile.exists()) await saveFile.delete();'),
    );
    expect(source, contains('restarting transfer.'));
    expect(source, contains('savePath: saveFile.path'));
  });

  test('receiver refuses redirects and generic non-media responses', () {
    final source = File('lib/features/transfer/data/media_receiver.dart')
        .readAsStringSync();

    expect(source, contains('request.followRedirects = false'));
    expect(source, contains("response.headers.value('X-Otya-Transfer')"));
    expect(source, contains("contentType.startsWith('audio/')"));
    expect(source, contains("contentType.startsWith('video/')"));
    expect(source, contains('response.contentLength'));
    expect(source, contains('_maxTransferBytes'));
  });
}
