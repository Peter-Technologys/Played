import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal media scans include OTYA received app storage', () {
    final source = File('lib/core/services/media_scanner_service.dart')
        .readAsStringSync();

    expect(source, contains('getExternalStorageDirectory()'));
    expect(source, contains("candidates.add('\${appExternal.path}/OTYA_Received')"));
    expect(source, contains('uniqueCandidates'));
  });

  test('completed Transfer refreshes the normal media library', () {
    final source = File('lib/features/transfer/presentation/transfer_screen.dart')
        .readAsStringSync();

    expect(source, contains('MediaRepository.instance.invalidate();'));
    expect(
      source,
      contains('ref.read(mediaLibraryProvider.notifier).refresh()'),
    );
    expect(source, isNot(contains('MediaScannerService.instance.scanDirectory(dir.path)')));
  });
}
