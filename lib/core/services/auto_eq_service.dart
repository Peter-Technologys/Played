import 'package:flutter/foundation.dart';

/// Legacy filename-based EQ suggestion model.
///
/// OTYA v1 no longer applies these guesses automatically: doing so could
/// override the user's saved Sound Tuner preference, and the old implementation
/// targeted Android's deprecated global audio session. The detector is retained
/// temporarily for compatibility/possible future UI suggestions only.
class EqPreset {
  const EqPreset({
    required this.name,
    required this.bass,
    required this.lowMid,
    required this.mid,
    required this.highMid,
    required this.treble,
  });

  final String name;
  final double bass;
  final double lowMid;
  final double mid;
  final double highMid;
  final double treble;

  static const flat = EqPreset(
    name: 'Flat',
    bass: 0,
    lowMid: 0,
    mid: 0,
    highMid: 0,
    treble: 0,
  );
}

class AutoEqService {
  AutoEqService._();
  static final AutoEqService instance = AutoEqService._();

  static const _rules = <_KeywordPreset>[
    _KeywordPreset(
      keywords: ['bass', 'bassline', 'dubstep', 'trap', 'drill'],
      preset: EqPreset(
        name: 'Bass Boost',
        bass: 6,
        lowMid: 4,
        mid: 1,
        highMid: -1,
        treble: -2,
      ),
    ),
    _KeywordPreset(
      keywords: ['classical', 'orchestra', 'symphony', 'concerto', 'sonata'],
      preset: EqPreset(
        name: 'Classical',
        bass: 3,
        lowMid: 1,
        mid: -1,
        highMid: 2,
        treble: 4,
      ),
    ),
    _KeywordPreset(
      keywords: ['hiphop', 'hip hop', 'hip-hop', 'rap', 'rnb', 'r&b'],
      preset: EqPreset(
        name: 'Hip-Hop',
        bass: 6,
        lowMid: 4,
        mid: 0,
        highMid: 2,
        treble: 1,
      ),
    ),
    _KeywordPreset(
      keywords: ['jazz', 'blues', 'swing', 'bebop'],
      preset: EqPreset(
        name: 'Jazz',
        bass: 3,
        lowMid: 2,
        mid: 0,
        highMid: 2,
        treble: 3,
      ),
    ),
    _KeywordPreset(
      keywords: ['rock', 'metal', 'punk', 'grunge', 'guitar'],
      preset: EqPreset(
        name: 'Rock',
        bass: 4,
        lowMid: 2,
        mid: -1,
        highMid: 2,
        treble: 4,
      ),
    ),
    _KeywordPreset(
      keywords: ['pop', 'dance', 'edm', 'house', 'techno'],
      preset: EqPreset(
        name: 'Pop',
        bass: 1,
        lowMid: 1,
        mid: 0,
        highMid: 2,
        treble: 3,
      ),
    ),
    _KeywordPreset(
      keywords: ['lofi', 'lo-fi', 'chill', 'ambient', 'sleep'],
      preset: EqPreset(
        name: 'Night',
        bass: -3,
        lowMid: -2,
        mid: 0,
        highMid: -2,
        treble: -4,
      ),
    ),
    _KeywordPreset(
      keywords: ['afrobeat', 'afro', 'afropop', 'highlife'],
      preset: EqPreset(
        name: 'Afrobeats',
        bass: 5,
        lowMid: 3,
        mid: 1,
        highMid: 2,
        treble: 2,
      ),
    ),
  ];

  EqPreset detectPreset(String filename) {
    final normalized = filename
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-.]'), ' ');
    for (final rule in _rules) {
      if (rule.keywords.any(normalized.contains)) return rule.preset;
    }
    return EqPreset.flat;
  }

  /// Compatibility no-op for older AudioPlayer call sites.
  ///
  /// Manual Sound Tuner preferences are now the only persistent EQ authority.
  Future<void> applyPreset(EqPreset preset) async {
    debugPrint(
      '[AutoEQ] Suggested ${preset.name}; automatic application is disabled in OTYA v1.',
    );
  }
}

class _KeywordPreset {
  const _KeywordPreset({required this.keywords, required this.preset});
  final List<String> keywords;
  final EqPreset preset;
}
