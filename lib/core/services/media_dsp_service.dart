import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OTYA-owned audio DSP applied inside the active MediaKit/libmpv player.
///
/// Android's `Equalizer` attached to audio session 0 is deprecated and can
/// affect the global output mix. OTYA instead owns a labelled libmpv audio
/// filter (`@otya-eq`) so changes affect only the current OTYA player and can
/// be replaced/removed without disturbing MediaKit's other audio filters.
class MediaDspService {
  MediaDspService._();
  static final MediaDspService instance = MediaDspService._();

  static const _gainsKey = 'otya_eq_gains_v2';
  static const _presetKey = 'otya_eq_preset_v2';
  static const _label = '@otya-eq';

  static const frequencies = <double>[60, 230, 910, 3600, 14000];
  static const labels = <String>['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];

  static const presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0],
    'Bass Boost': [6, 4, 1, -1, -2],
    'Rock': [4, 2, -1, 2, 4],
    'Pop': [1, 1, 0, 2, 3],
    'Jazz': [3, 2, 0, 2, 3],
    'Vocal': [-1, 0, 3, 4, 2],
    'Night': [-3, -2, 0, -2, -4],
  };

  Future<List<double>> loadGains() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_gainsKey);
    if (raw == null || raw.length != frequencies.length) {
      return List<double>.from(presets['Flat']!);
    }
    final values = raw.map(double.tryParse).toList();
    if (values.any((value) => value == null)) {
      return List<double>.from(presets['Flat']!);
    }
    return values.cast<double>();
  }

  Future<String> loadPreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_presetKey) ?? 'Flat';
  }

  Future<void> save({required List<double> gains, required String preset}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _gainsKey,
      gains.map((gain) => gain.toStringAsFixed(2)).toList(growable: false),
    );
    await prefs.setString(_presetKey, preset);
  }

  Future<bool> applySaved(Player player) async {
    final gains = await loadGains();
    return apply(player, gains);
  }

  Future<bool> apply(Player player, List<double> gains) async {
    if (gains.length != frequencies.length) return false;
    final platform = player.platform;
    if (platform is! NativePlayer) return false;

    try {
      // Remove only OTYA's own filter. Other filters (for example speed/pitch
      // correction) remain untouched.
      try {
        await platform.command(<String>['change-list', 'af', 'remove', _label]);
      } catch (_) {
        // Removing a filter that is not present is harmless.
      }

      if (gains.every((gain) => gain.abs() < .01)) return true;

      final filters = <String>[];
      for (var i = 0; i < frequencies.length; i++) {
        final gain = gains[i].clamp(-10.0, 10.0).toStringAsFixed(2);
        final frequency = frequencies[i].toStringAsFixed(0);
        filters.add('equalizer=f=$frequency:t=q:w=1:g=$gain');
      }
      final chain = '$_label:lavfi=[${filters.join(',')}]';
      await platform.command(<String>['change-list', 'af', 'append', chain]);
      return true;
    } catch (error, stack) {
      debugPrint('[MediaDSP] Could not apply OTYA EQ: $error\n$stack');
      return false;
    }
  }
}
