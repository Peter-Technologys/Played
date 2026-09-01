import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = File('lib/core/services/ffmpeg_service.dart').readAsStringSync();
  final plugin = File(
    'packages/otya_media_tools/android/src/main/kotlin/com/petersmartlink/otya_media_tools/OtyaMediaToolsPlugin.kt',
  ).readAsStringSync();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('Flutter media tools use the isolated v2 native plugin', () {
    expect(pubspec, contains('otya_media_tools:'));
    expect(pubspec, contains('path: packages/otya_media_tools'));
    expect(service, contains("MethodChannel('com.otyaplayer.app/media_tools_v2')"));
    expect(service, contains('lastErrorMessage'));
  });

  test('native trim sizes its sample buffer from media metadata', () {
    expect(plugin, contains('MediaFormat.KEY_MAX_INPUT_SIZE'));
    expect(plugin, contains('ByteBuffer.allocateDirect(bufferSize)'));
    expect(plugin, isNot(contains('ByteBuffer.allocate(1024 * 1024)')));
    expect(plugin, contains('MAX_BUFFER_BYTES = 32 * 1024 * 1024'));
  });

  test('native trim preserves a common A/V timeline and requires video', () {
    expect(plugin, contains('findPlayableOrigin'));
    expect(plugin, contains('info.presentationTimeUs = pts - originUs'));
    expect(plugin, contains('if (!hasVideo)'));
    expect(plugin, contains('videoSamples == 0'));
  });

  test('native trim exposes actionable safe failure codes', () {
    for (final code in [
      'TRIM_FILE_UNREADABLE',
      'TRIM_UNSUPPORTED_FORMAT',
      'TRIM_SAMPLE_TOO_LARGE',
      'TRIM_EMPTY_RANGE',
      'TRIM_MUX_FAILED',
      'MEDIA_SAVE_FAILED',
    ]) {
      expect(plugin, contains(code), reason: 'Missing $code');
    }
  });
}
