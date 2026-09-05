import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File(
    'lib/features/player/presentation/audio_player_screen.dart',
  ).readAsStringSync();
  final view = File(
    'lib/features/player/presentation/widgets/audio_player_now_playing_view.dart',
  ).readAsStringSync();

  test('audio notifier remains the playback and notification owner', () {
    expect(screen, contains('final Player _player = Player('));
    expect(screen, contains('AudioHandlerSingleton.instance.attachPlayer(_player)'));
    expect(screen, contains('MediaNotificationService.instance.show('));
    expect(
      screen,
      contains("PlaybackCoordinator.instance.register(_player, 'audio')"),
    );

    expect(view, isNot(contains('Player(')));
    expect(view, isNot(contains('AudioHandlerSingleton')));
    expect(view, isNot(contains('MediaNotificationService')));
    expect(view, isNot(contains('PlaybackCoordinator')));
    expect(view, isNot(contains('StreamSubscription')));
  });

  test('now playing layout is presentation-only and delegated by the screen', () {
    expect(
      screen,
      contains("part 'widgets/audio_player_now_playing_view.dart';"),
    );
    expect(screen, contains('return _AudioPlayerNowPlayingView('));
    expect(view, contains('class _AudioPlayerNowPlayingView'));
    expect(view, contains('WallpaperScaffold('));
    expect(view, contains('_AlbumArt('));
    expect(view, contains('_SeekBar('));
  });
}
