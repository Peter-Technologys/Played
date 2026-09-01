import 'package:flutter_test/flutter_test.dart';
import 'package:otya_player/core/services/next_action_contract.dart';

void main() {
  test('allows only approved user-side navigation routes', () {
    final action = NextUserActionProposal.fromJson({
      'type': 'navigate',
      'arguments': {'route': '/settings'},
    });
    expect(action.type, NextUserActionType.navigate);
    expect(action.arguments['route'], '/settings');

    expect(
      () => NextUserActionProposal.fromJson({
        'type': 'navigate',
        'arguments': {'route': '/admin'},
      }),
      throwsFormatException,
    );
  });

  test('model cannot supply arbitrary filesystem paths for local playback', () {
    expect(
      () => NextUserActionProposal.fromJson({
        'type': 'play_local_media',
        'arguments': {
          'media_id': 'media-123',
          'file_path': '/storage/emulated/0/secret.mp3',
        },
      }),
      throwsFormatException,
    );

    final action = NextUserActionProposal.fromJson({
      'type': 'play_local_media',
      'arguments': {'media_id': 'media-123'},
    });
    expect(action.arguments, {'media_id': 'media-123'});
  });

  test('unknown owner, destructive and arbitrary action types fail closed', () {
    for (final type in [
      'deploy_production',
      'delete_account',
      'delete_file',
      'send_email',
      'post_telegram',
      'run_shell',
    ]) {
      expect(
        () => NextUserActionProposal.fromJson({
          'type': type,
          'arguments': <String, Object?>{},
        }),
        throwsFormatException,
        reason: '$type must not enter the user-side Next registry',
      );
    }
  });

  test('playback control has a narrow reversible command set', () {
    for (final command in ['play', 'pause', 'next', 'previous']) {
      final action = NextUserActionProposal.fromJson({
        'type': 'playback_control',
        'arguments': {'command': command},
      });
      expect(action.risk, NextUserActionRisk.reversible);
      expect(action.requiresConfirmation, isFalse);
    }

    expect(
      () => NextUserActionProposal.fromJson({
        'type': 'playback_control',
        'arguments': {'command': 'delete'},
      }),
      throwsFormatException,
    );
  });

  test('read-only app state is explicitly allowlisted', () {
    for (final field in ['version', 'playback', 'media_permissions', 'network']) {
      final action = NextUserActionProposal.fromJson({
        'type': 'read_app_state',
        'arguments': {'field': field},
      });
      expect(action.risk, NextUserActionRisk.readOnly);
    }

    expect(
      () => NextUserActionProposal.fromJson({
        'type': 'read_app_state',
        'arguments': {'field': 'credentials'},
      }),
      throwsFormatException,
    );
  });
}
