import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Storage uses the shared Otya surface and current media colors', () {
    final source = File(
      'lib/features/settings/presentation/storage_analyzer_screen.dart',
    ).readAsStringSync();

    expect(source, contains('WallpaperScaffold('));
    expect(source, contains("('Videos', r.videoBytes, AppColors.brandCyan)"));
    expect(source, contains("('Audio', r.audioBytes, AppColors.brandBlue)"));
    expect(source, isNot(contains('Color(0xFF7C3AED)')));
    expect(source, contains('StorageAnalyzerService.instance.analyze()'));
    expect(source, contains('DuplicateDetectorService.instance.findDuplicates'));
    expect(source, contains('StorageAnalyzerService.instance.purgeCache()'));
  });

  test('local Trim uses the shared Otya surface and keeps processing local', () {
    final source = File(
      'lib/features/tools/whatsapp_trimmer_screen.dart',
    ).readAsStringSync();

    expect(source, contains('WallpaperScaffold('));
    expect(source, contains('AppColors.brandCyan'));
    expect(source, contains('FfmpegService.instance.trimVideo('));
    expect(source, contains('videoPath: mediaItem.filePath'));
    expect(source, contains('final clipLength = duration.clamp(0.0, 30.0)'));
    expect(source, contains('Otya trims the original video without uploading it.'));
  });
}
