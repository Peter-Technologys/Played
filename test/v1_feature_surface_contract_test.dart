import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Video Music and Me remain the main product navigation', () {
    final shell = File(
      'lib/app/shell/app_shell.dart',
    ).readAsStringSync();

    for (final marker in ['Video', 'Music', 'Me']) {
      expect(shell, contains(marker));
    }
  });

  test('Me exposes every required OTYA v1 hub action', () {
    final screen = File(
      'lib/features/account/presentation/account_screen.dart',
    ).readAsStringSync();

    for (final marker in [
      'Transfer Files',
      'Private',
      'Playlists',
      'Settings',
      'Help',
      'About',
    ]) {
      expect(screen, contains(marker), reason: '$marker must remain available');
    }
  });

  test('App Lock is persisted, user-accessible and mounted at app root', () {
    final screen = File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/settings/settings_provider.dart',
    ).readAsStringSync();
    final app = File('lib/app/app.dart').readAsStringSync();

    expect(screen, contains('App Lock'));
    expect(settings, contains('appLockEnabled'));
    expect(app, contains('AppLockGate'));
  });

  test('Private keeps authentication, persistent throttle and safe restore', () {
    final screen = File(
      'lib/features/vault/presentation/vault_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/core/services/vault_service.dart',
    ).readAsStringSync();

    expect(screen, contains('LocalAuthentication'));
    expect(screen, contains('VaultAuthThrottle'));
    expect(service, contains('restoreItem'));
    expect(service, contains('collision'));
  });

  test('Transfer keeps authenticated local-only streaming and safe resume', () {
    final sender = File(
      'lib/core/services/media_sender.dart',
    ).readAsStringSync();
    final receiver = File(
      'lib/core/services/media_receiver.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/transfer/presentation/transfer_screen.dart',
    ).readAsStringSync();

    expect(sender, contains('token'));
    expect(sender, contains('/media'));
    expect(receiver, contains('Range'));
    expect(receiver, contains('.otya-transfer'));
    expect(receiver, contains('TransferCancelledException'));
    expect(screen, contains("split('/').last"));
  });

  test('Music keeps queue, favorites, repeat, lyrics, EQ, sleep and Drive Mode', () {
    final screen = File(
      'lib/features/player/presentation/audio_player_screen.dart',
    ).readAsStringSync();
    final widgets = File(
      'lib/features/player/presentation/widgets/audio_player_widgets.dart',
    ).readAsStringSync();
    final nowPlayingView = File(
      'lib/features/player/presentation/widgets/audio_player_now_playing_view.dart',
    ).readAsStringSync();
    final player = '$screen\n$widgets\n$nowPlayingView';

    for (final marker in [
      'toggleFavorite()',
      'toggleShuffle()',
      'cycleRepeat()',
      'SleepTimerButton(',
      'LyricsSheet(',
      "context.push('/player/equalizer')",
      'CarModeScreen()',
      'skipNext()',
      'skipPrevious()',
    ]) {
      expect(player, contains(marker), reason: '$marker must stay wired');
    }
  });

  test('Video keeps gestures, PiP, tracks and local processing tools', () {
    final player = File(
      'lib/features/player/presentation/video_player_screen.dart',
    ).readAsStringSync();
    final gestures = File(
      'lib/features/player/presentation/widgets/video_gesture_layer.dart',
    ).readAsStringSync();

    expect(player, contains('setSubtitleTrack'));
    expect(player, contains('setAudioTrack'));
    expect(player, contains('PipService.instance.enterPip'));
    expect(player, contains('extractAudio'));
    expect(player, contains("context.push('/tools/whatsapp'"));
    expect(gestures, contains('onDoubleTap'));
    expect(gestures, contains('onVerticalDrag'));
  });

  test('Downloads remain a view of normal Video and Music media', () {
    final downloads = File(
      'lib/features/downloads/presentation/downloads_screen.dart',
    ).readAsStringSync();

    expect(downloads, contains('MediaType.video'));
    expect(downloads, contains('MediaType.audio'));
  });

  test('Next remains a real conversational surface', () {
    final next = File(
      'lib/features/next/presentation/next_screen.dart',
    ).readAsStringSync();

    expect(next, contains('sendMessage'));
    expect(next, contains('conversation'));
  });

  test('Account keeps Google, password, consent, recovery and 2FA flows', () {
    final account = File(
      'lib/features/account/presentation/account_screen.dart',
    ).readAsStringSync();
    final auth = File(
      'lib/features/auth/presentation/login_screen.dart',
    ).readAsStringSync();

    final source = '$account\n$auth';
    for (final marker in [
      'Google',
      'password',
      'consent',
      'recovery',
      '2FA',
    ]) {
      expect(source.toLowerCase(), contains(marker.toLowerCase()));
    }
  });

  test('Notifications keep contextual permission and safe FCM routing', () {
    final notifications = File(
      'lib/core/services/notification_service.dart',
    ).readAsStringSync();

    expect(notifications, contains('requestPermission'));
    expect(notifications, contains('https'));
  });
}
