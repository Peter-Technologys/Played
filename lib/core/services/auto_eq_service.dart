// lib/core/services/auto_eq_service.dart
//
// AutoEqService — detects genre/mood from filename keywords and returns a
// 5-band EQ preset. Pure Dart, no external AI SDK.
//
// Bands (dB, range -12 to +12):
//   bass    ~60–250 Hz
//   lowMid  ~250–500 Hz
//   mid     ~500–2000 Hz
//   highMid ~2000–6000 Hz
//   treble  ~6000–16000 Hz

/// A 5-band EQ preset with values in dB (-12 to +12).
class EqPreset {
  final double bass;
  final double lowMid;
  final double mid;
  final double highMid;
  final double treble;

  /// Human-readable name for this preset (e.g. "Hip-Hop", "Classical").
  final String name;

  const EqPreset({
    required this.name,
    required this.bass,
    required this.lowMid,
    required this.mid,
    required this.highMid,
    required this.treble,
  });

  /// Flat / neutral preset — no EQ applied.
  static const EqPreset flat = EqPreset(
    name:    'Flat',
    bass:    0,
    lowMid:  0,
    mid:     0,
    highMid: 0,
    treble:  0,
  );

  @override
  String toString() =>
      'EqPreset($name: bass=$bass, lowMid=$lowMid, mid=$mid, highMid=$highMid, treble=$treble)';
}

/// Detects an EQ preset from a filename using keyword matching.
class AutoEqService {
  AutoEqService._();
  static final AutoEqService instance = AutoEqService._();

  // ── Keyword → preset mapping ──────────────────────────────────────────────
  // Each entry is a list of keywords; the first match wins.
  // Keywords are matched case-insensitively against the normalised filename.

  static const List<_KeywordPreset> _rules = [
    _KeywordPreset(
      keywords: ['bass', 'bassline', 'sub', 'dubstep', 'trap', 'drill'],
      preset: EqPreset(
        name:    'Bass Boost',
        bass:    8.0,
        lowMid:  3.0,
        mid:     -1.0,
        highMid: -2.0,
        treble:  -1.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['acoustic', 'unplugged', 'folk', 'singer', 'songwriter'],
      preset: EqPreset(
        name:    'Acoustic',
        bass:    2.0,
        lowMid:  1.0,
        mid:     3.0,
        highMid: 4.0,
        treble:  3.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['classical', 'orchestra', 'symphony', 'concerto', 'sonata', 'opera', 'piano'],
      preset: EqPreset(
        name:    'Classical',
        bass:    3.0,
        lowMid:  0.0,
        mid:     -1.0,
        highMid: 2.0,
        treble:  4.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['hiphop', 'hip_hop', 'hip-hop', 'rap', 'rnb', 'r&b', 'soul'],
      preset: EqPreset(
        name:    'Hip-Hop',
        bass:    6.0,
        lowMid:  4.0,
        mid:     -1.0,
        highMid: 1.0,
        treble:  2.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['jazz', 'blues', 'swing', 'bebop', 'bossa'],
      preset: EqPreset(
        name:    'Jazz',
        bass:    2.0,
        lowMid:  3.0,
        mid:     1.0,
        highMid: 3.0,
        treble:  4.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['rock', 'metal', 'punk', 'grunge', 'alternative', 'indie', 'guitar'],
      preset: EqPreset(
        name:    'Rock',
        bass:    5.0,
        lowMid:  2.0,
        mid:     -1.0,
        highMid: 3.0,
        treble:  4.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['pop', 'dance', 'edm', 'electro', 'house', 'techno', 'club'],
      preset: EqPreset(
        name:    'Pop / Dance',
        bass:    4.0,
        lowMid:  1.0,
        mid:     0.0,
        highMid: 3.0,
        treble:  4.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['lofi', 'lo-fi', 'lo_fi', 'chill', 'ambient', 'sleep', 'relax'],
      preset: EqPreset(
        name:    'Lo-Fi / Chill',
        bass:    3.0,
        lowMid:  2.0,
        mid:     -2.0,
        highMid: -3.0,
        treble:  -4.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['gospel', 'worship', 'praise', 'hymn', 'choir'],
      preset: EqPreset(
        name:    'Gospel',
        bass:    3.0,
        lowMid:  2.0,
        mid:     3.0,
        highMid: 4.0,
        treble:  3.0,
      ),
    ),
    _KeywordPreset(
      keywords: ['afrobeat', 'afro', 'afropop', 'highlife', 'afroswing'],
      preset: EqPreset(
        name:    'Afrobeats',
        bass:    5.0,
        lowMid:  3.0,
        mid:     1.0,
        highMid: 2.0,
        treble:  2.0,
      ),
    ),
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Detects an [EqPreset] from [filename] by matching genre/mood keywords.
  /// Returns [EqPreset.flat] when no keyword matches.
  EqPreset detectPreset(String filename) {
    // Normalise: lowercase, replace separators with spaces.
    final normalised = filename
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-.]'), ' ');

    for (final rule in _rules) {
      for (final kw in rule.keywords) {
        if (normalised.contains(kw)) {
          return rule.preset;
        }
      }
    }

    return EqPreset.flat;
  }
}

class _KeywordPreset {
  final List<String> keywords;
  final EqPreset preset;
  const _KeywordPreset({required this.keywords, required this.preset});
}
