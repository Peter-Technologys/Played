import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otya_player/features/air_drop/data/media_receiver.dart';

void main() {
  const tokenA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const tokenB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const tokenC = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  test('MediaReceiver resumes only a matching transfer partial', () async {
    final source = List<int>.generate(4096, (index) => index % 251);
    final temp = await Directory.systemTemp.createTemp('otya_transfer_test_');
    final target = File('${temp.path}/received.bin');
    const existing = 1379;

    String? receivedRange;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = 'http://127.0.0.1:${server.port}/media?t=$tokenA';
    await target.writeAsBytes(source.take(existing).toList(), flush: true);
    await File('${target.path}.otya-transfer')
        .writeAsString('127.0.0.1:${server.port}/media|$tokenA', flush: true);

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
      final result = await receiver.download(url: url, savePath: target.path);

      expect(receivedRange, 'bytes=$existing-');
      expect(result.path, target.path);
      expect(await result.readAsBytes(), source);
      expect(await File('${target.path}.otya-transfer').exists(), isFalse);
    } finally {
      await server.close(force: true);
      await temp.delete(recursive: true);
    }
  });

  test('MediaReceiver does not append a different transfer to same-name file', () async {
    final oldBytes = List<int>.filled(700, 7);
    final newBytes = List<int>.generate(2048, (index) => (index * 7) % 253);
    final temp = await Directory.systemTemp.createTemp('otya_transfer_test_');
    final target = File('${temp.path}/received.bin');
    await target.writeAsBytes(oldBytes, flush: true);

    String? receivedRange;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      receivedRange = request.headers.value(HttpHeaders.rangeHeader);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, newBytes.length)
        ..add(newBytes);
      await request.response.close();
    });

    try {
      final receiver = MediaReceiver();
      final result = await receiver.download(
        url: 'http://127.0.0.1:${server.port}/media?t=$tokenB',
        savePath: target.path,
      );

      expect(receivedRange, isNull);
      expect(result.path, isNot(target.path));
      expect(await target.readAsBytes(), oldBytes);
      expect(await result.readAsBytes(), newBytes);
    } finally {
      await server.close(force: true);
      await temp.delete(recursive: true);
    }
  });

  test('MediaReceiver restarts cleanly when server ignores Range', () async {
    final source = List<int>.generate(2048, (index) => (index * 7) % 253);
    final temp = await Directory.systemTemp.createTemp('otya_transfer_test_');
    final target = File('${temp.path}/received.bin');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = 'http://127.0.0.1:${server.port}/media?t=$tokenC';
    await target.writeAsBytes(const [1, 2, 3, 4, 5], flush: true);
    await File('${target.path}.otya-transfer')
        .writeAsString('127.0.0.1:${server.port}/media|$tokenC', flush: true);

    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentLengthHeader, source.length)
        ..add(source);
      await request.response.close();
    });

    try {
      final receiver = MediaReceiver();
      final result = await receiver.download(url: url, savePath: target.path);

      expect(result.path, target.path);
      expect(await result.readAsBytes(), source);
    } finally {
      await server.close(force: true);
      await temp.delete(recursive: true);
    }
  });

  test('MediaReceiver rejects non-local or malformed transfer URLs', () async {
    final temp = await Directory.systemTemp.createTemp('otya_transfer_test_');
    final receiver = MediaReceiver();
    try {
      await expectLater(
        receiver.download(
          url: 'http://example.com/media?t=$tokenA',
          savePath: '${temp.path}/remote.bin',
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        receiver.download(
          url: 'https://127.0.0.1/media?t=$tokenA',
          savePath: '${temp.path}/https.bin',
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        receiver.download(
          url: 'http://127.0.0.1/media?t=short',
          savePath: '${temp.path}/short.bin',
        ),
        throwsA(isA<FormatException>()),
      );
    } finally {
      await temp.delete(recursive: true);
    }
  });
}
