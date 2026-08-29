import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otya_player/features/air_drop/data/media_receiver.dart';

void main() {
  test('MediaReceiver resumes from an existing partial file', () async {
    final source = List<int>.generate(4096, (index) => index % 251);
    final temp = await Directory.systemTemp.createTemp('otya_transfer_test_');
    final target = File('${temp.path}/received.bin');
    const existing = 1379;
    await target.writeAsBytes(source.take(existing).toList(), flush: true);

    String? receivedRange;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      receivedRange = request.headers.value(HttpHeaders.rangeHeader);
      final start = receivedRange == null
          ? 0
          : int.parse(receivedRange!.substring('bytes='.length).split('-').first);
      final bytes = source.sublist(start);
      request.response
        ..statusCode = start > 0 ? HttpStatus.partialContent : HttpStatus.ok
        ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..headers.set(HttpHeaders.contentLengthHeader, bytes.length);
      if (start > 0) {
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${source.length - 1}/${source.length}',
        );
      }
      request.response.add(bytes);
      await request.response.close();
    });

    try {
      final receiver = MediaReceiver();
      final result = await receiver.download(
        url: 'http://127.0.0.1:${server.port}/media?t=test',
        savePath: target.path,
      );

      expect(receivedRange, 'bytes=$existing-');
      expect(await result.readAsBytes(), source);
    } finally {
      await server.close(force: true);
      await temp.delete(recursive: true);
    }
  });

  test('MediaReceiver restarts cleanly when server ignores Range', () async {
    final source = List<int>.generate(2048, (index) => (index * 7) % 253);
    final temp = await Directory.systemTemp.createTemp('otya_transfer_test_');
    final target = File('${temp.path}/received.bin');
    await target.writeAsBytes(const [1, 2, 3, 4, 5], flush: true);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, source.length)
        ..add(source);
      await request.response.close();
    });

    try {
      final receiver = MediaReceiver();
      final result = await receiver.download(
        url: 'http://127.0.0.1:${server.port}/media',
        savePath: target.path,
      );

      expect(await result.readAsBytes(), source);
    } finally {
      await server.close(force: true);
      await temp.delete(recursive: true);
    }
  });
}
