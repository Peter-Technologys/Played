import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MediaStore items are identified by mediaStoreId, not artwork', () {
    final source =
        File('lib/features/my_space/data/media_repository.dart').readAsStringSync();

    expect(source, contains('e.mediaStoreId != null'));
    expect(source, contains('e.mediaStoreId == null'));
    expect(source, isNot(contains('e.albumArtPath != null')));
    expect(source, isNot(contains('e.albumArtPath == null')));
  });
}
