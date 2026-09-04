import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('background media scans never request Android permission directly', () {
    final scanner = File('lib/core/services/media_scanner_service.dart')
        .readAsStringSync();

    expect(scanner, contains('PermissionHelper.hasMediaPermissions()'));
    expect(scanner, isNot(contains('PermissionHelper.requestMediaPermissions()')));
    expect(scanner, contains('class MediaPermissionRequiredException'));
    expect(scanner, contains('throw const MediaPermissionRequiredException();'));
  });

  test('permission recovery remains explicit and user-driven', () {
    final screen = File('lib/shared/widgets/permission_denied_screen.dart')
        .readAsStringSync();

    expect(
      screen,
      contains('PermissionHelper.showMediaPermissionRationale(context)'),
    );
    expect(screen, contains("'Allow media access'"));
    expect(screen, contains('openAppSettings()'));
    expect(screen, contains('if (_requesting) return;'));
  });

  test('revoked media access is not hidden behind stale library cache', () {
    final provider = File(
      'lib/features/my_space/presentation/providers/my_space_provider.dart',
    ).readAsStringSync();

    expect(
      provider,
      contains('if (error is MediaPermissionRequiredException)'),
    );
    expect(provider, contains('state = AsyncError(error, stack);'));
    expect(
      provider,
      contains('Permission loss is authoritative.'),
    );
  });
}
