import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a 416 response is accepted only when local and remote lengths match', () {
    final source = File('lib/features/transfer/data/media_receiver.dart')
        .readAsStringSync();

    expect(source, contains('_lengthFromUnsatisfiedRange(response)'));
    expect(
      source,
      contains('remoteLength != null && existingBytes == remoteLength'),
    );
    expect(source, contains("RegExp(r'^bytes \\*/(\\d+)\$')"));
  });

  test('invalid resume offsets discard suspect bytes and restart', () {
    final source = File('lib/features/transfer/data/media_receiver.dart')
        .readAsStringSync();

    expect(source, contains('if (await saveFile.exists()) await saveFile.delete();'));
    expect(source, contains('Resume offset is invalid; restarting transfer.'));
    expect(source, contains('savePath: saveFile.path'));
  });
}
