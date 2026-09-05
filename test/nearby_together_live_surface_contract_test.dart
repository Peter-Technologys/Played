import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/together/presentation/nearby_together_live_surface.dart',
  ).readAsStringSync();
  final player = File(
    'lib/features/player/presentation/video_player_screen.dart',
  ).readAsStringSync();

  test('Nearby Together reuses the one room UI and repaints from runtime', () {
    expect(source, contains('AnimatedBuilder('));
    expect(source, contains('animation: runtime'));
    expect(source, contains('TogetherRoomContent('));
    expect(source, contains('messages: runtime.state.messages'));
    expect(source, isNot(contains('MediaKitEngine(')));
    expect(source, isNot(contains('Player(')));
  });

  test('live Together remains a temporary overlay instead of a new route', () {
    expect(source, contains('showModalBottomSheet<void>'));
    expect(source, contains('showGeneralDialog<void>'));
    expect(source, isNot(contains('GoRoute(')));
    expect(source, isNot(contains('Navigator.push')));
  });

  test('video player opens the live Nearby Together surface', () {
    expect(
      player,
      contains("import '../../together/presentation/nearby_together_live_surface.dart';"),
    );
    expect(player, contains('showNearbyTogetherLiveRoomSurface('));
    expect(player, isNot(contains('showTogetherRoomSurface(')));
  });
}
