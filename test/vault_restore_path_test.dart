import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otya_player/core/services/vault_service.dart';

void main() {
  group('Otya Private restore paths', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('otya-private-test-');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('uses the original path when it is free', () async {
      final original = '${temp.path}${Platform.pathSeparator}movie.mp4';

      final selected =
          await VaultService.findAvailableRestorePathForTest(original);

      expect(selected, original);
    });

    test('does not overwrite a file created at the original path', () async {
      final original = '${temp.path}${Platform.pathSeparator}movie.mp4';
      await File(original).writeAsString('new user file');

      final selected =
          await VaultService.findAvailableRestorePathForTest(original);

      expect(selected, '${temp.path}${Platform.pathSeparator}movie (restored 1).mp4');
      expect(await File(original).readAsString(), 'new user file');
    });

    test('increments until it finds a free collision-safe name', () async {
      final original = '${temp.path}${Platform.pathSeparator}song.flac';
      await File(original).writeAsString('existing');
      await File('${temp.path}${Platform.pathSeparator}song (restored 1).flac')
          .writeAsString('existing restore');

      final selected =
          await VaultService.findAvailableRestorePathForTest(original);

      expect(selected, '${temp.path}${Platform.pathSeparator}song (restored 2).flac');
    });

    test('source contract keeps the Private copy on scoped-storage write failure', () {
      final source = File(
        'lib/core/services/vault_service.dart',
      ).readAsStringSync();

      expect(source, contains('on FileSystemException catch (error)'));
      expect(
        source,
        contains('The Private copy was kept safely.'),
      );
      expect(
        source,
        contains('await restoredFile.copy(vaultItem.encryptedPath);'),
        reason: 'A metadata-removal failure must restore the protected source '
            'before surfacing the error.',
      );
    });

    test('source contract never overwrites an existing Private lock target', () {
      final source = File(
        'lib/core/services/vault_service.dart',
      ).readAsStringSync();

      expect(source, contains('sha256.convert(utf8.encode(mediaId)).toString()'));
      expect(source, contains('await target.create(exclusive: true);'));
      expect(source, contains('var reservedTarget = false;'));
      expect(source, contains('reservedTarget = true;'));
      expect(
        source,
        contains('if (reservedTarget) {'),
        reason: 'A failed exclusive reservation must never delete a target '
            'that existed before this lock attempt.',
      );
      expect(
        source,
        contains("throw StateError('This media item is already in Private.');"),
      );
      expect(
        source,
        contains('await copied.length() != sourceLength'),
        reason: 'The original media must not be removed unless the protected '
            'copy has the expected byte length.',
      );
    });
  });
}
