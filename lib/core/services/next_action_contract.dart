enum NextUserActionType {
  navigate,
  searchLocalMedia,
  playLocalMedia,
  playbackControl,
  readAppState,
}

enum NextUserActionRisk {
  readOnly,
  reversible,
}

class NextUserActionProposal {
  const NextUserActionProposal({
    required this.type,
    required this.arguments,
    required this.risk,
  });

  final NextUserActionType type;
  final Map<String, Object?> arguments;
  final NextUserActionRisk risk;

  bool get requiresConfirmation => false;

  static const _allowedRoutes = <String>{
    '/music',
    '/video',
    '/me',
    '/settings',
    '/about',
    '/transfer',
    '/vault',
    '/playlists',
    '/history',
  };

  static const _playbackCommands = <String>{
    'play',
    'pause',
    'next',
    'previous',
  };

  factory NextUserActionProposal.fromJson(Map<String, Object?> json) {
    final type = _parseType(json['type']);
    final rawArguments = json['arguments'];
    if (rawArguments is! Map) {
      throw const FormatException('Next action arguments must be an object.');
    }
    final arguments = rawArguments.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    switch (type) {
      case NextUserActionType.navigate:
        final route = _requiredString(arguments, 'route');
        if (!_allowedRoutes.contains(route)) {
          throw const FormatException('Next cannot navigate to this route.');
        }
        return NextUserActionProposal(
          type: type,
          arguments: {'route': route},
          risk: NextUserActionRisk.reversible,
        );

      case NextUserActionType.searchLocalMedia:
        final query = _requiredString(arguments, 'query', maxLength: 200);
        return NextUserActionProposal(
          type: type,
          arguments: {'query': query},
          risk: NextUserActionRisk.readOnly,
        );

      case NextUserActionType.playLocalMedia:
        final mediaId = _requiredString(arguments, 'media_id', maxLength: 200);
        if (arguments.containsKey('file_path') || arguments.containsKey('path')) {
          throw const FormatException(
            'Next must resolve local media by app-owned ID, never by model-supplied path.',
          );
        }
        return NextUserActionProposal(
          type: type,
          arguments: {'media_id': mediaId},
          risk: NextUserActionRisk.reversible,
        );

      case NextUserActionType.playbackControl:
        final command = _requiredString(arguments, 'command', maxLength: 20);
        if (!_playbackCommands.contains(command)) {
          throw const FormatException('Unsupported playback command.');
        }
        return NextUserActionProposal(
          type: type,
          arguments: {'command': command},
          risk: NextUserActionRisk.reversible,
        );

      case NextUserActionType.readAppState:
        final field = _requiredString(arguments, 'field', maxLength: 60);
        const allowedFields = <String>{
          'version',
          'playback',
          'media_permissions',
          'network',
        };
        if (!allowedFields.contains(field)) {
          throw const FormatException('Next cannot read this app state field.');
        }
        return NextUserActionProposal(
          type: type,
          arguments: {'field': field},
          risk: NextUserActionRisk.readOnly,
        );
    }
  }

  static NextUserActionType _parseType(Object? value) {
    switch (value) {
      case 'navigate':
        return NextUserActionType.navigate;
      case 'search_local_media':
        return NextUserActionType.searchLocalMedia;
      case 'play_local_media':
        return NextUserActionType.playLocalMedia;
      case 'playback_control':
        return NextUserActionType.playbackControl;
      case 'read_app_state':
        return NextUserActionType.readAppState;
      default:
        throw const FormatException('Unknown or disallowed Next action.');
    }
  }

  static String _requiredString(
    Map<String, Object?> arguments,
    String key, {
    int maxLength = 300,
  }) {
    final value = arguments[key];
    if (value is! String || value.trim().isEmpty || value.length > maxLength) {
      throw FormatException('Invalid Next action argument: $key.');
    }
    return value.trim();
  }
}
