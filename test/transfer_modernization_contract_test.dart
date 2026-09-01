import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/transfer/presentation/transfer_screen.dart',
  ).readAsStringSync();

  test('Transfer explains and enforces the local-only trust boundary', () {
    expect(source, contains('Nearby. Direct. No upload.'));
    expect(source, contains('no OTYA cloud upload'));
    expect(source, contains("uri.scheme != 'http'"));
    expect(source, contains('_isPrivateHost(uri.host)'));
    expect(source, contains('same Wi-Fi or hotspot'));
  });

  test('Transfer has explicit send receive progress success and error states', () {
    expect(source, contains("ValueKey('send-ready')"));
    expect(source, contains("ValueKey('send-picker')"));
    expect(source, contains("ValueKey('receive-scan')"));
    expect(source, contains("ValueKey('receiving')"));
    expect(source, contains("ValueKey('receive-done')"));
    expect(source, contains('_ErrorCard'));
    expect(source, contains('LinearProgressIndicator'));
    expect(source, contains('Receive another'));
  });
}
