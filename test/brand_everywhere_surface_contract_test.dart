import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user-facing utility and recovery surfaces use the shared Otya backdrop', () {
    final paths = <String>[
      'lib/features/auth/forgot_password_screen.dart',
      'lib/features/my_space/presentation/folder_browser_screen.dart',
      'lib/features/my_space/presentation/playback_history_screen.dart',
      'lib/features/player/presentation/equalizer_screen.dart',
      'lib/features/profile/whats_new_screen.dart',
      'lib/features/settings/app_lock_screen.dart',
      'lib/features/settings/presentation/about_screen.dart',
      'lib/features/settings/presentation/privacy_policy_screen.dart',
      'lib/features/video/presentation/video_tab_screen.dart',
      'lib/shared/widgets/error_screen.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('WallpaperScaffold('),
        reason: '$path must use the shared Otya visual foundation',
      );
    }
  });

  test('password recovery keeps current Otya identity and readable action states', () {
    final source = File(
      'lib/features/auth/forgot_password_screen.dart',
    ).readAsStringSync();

    expect(source, contains('OtyaMark(size: 34)'));
    expect(source, contains("'Otya account recovery'"));
    expect(source, contains('backgroundColor: AppColors.brandBlue'));
    expect(source, contains('foregroundColor: Colors.white'));
    expect(source, contains('CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)'));
  });

  test('full-screen video playback stays a neutral black media canvas', () {
    final source = File(
      'lib/features/player/presentation/video_player_screen.dart',
    ).readAsStringSync();

    expect(source, contains('backgroundColor: Colors.black'));
    expect(source, isNot(contains('WallpaperScaffold(')));
  });
}
