import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last playback speed used for each media item.
/// Key: 'speed_<mediaId>'  Value: double as string
class SpeedMemoryService {
  SpeedMemoryService._();
  static final SpeedMemoryService instance = SpeedMemoryService._();

  static const _prefix = 'speed_';

  // Cached instance — avoids a platform-channel round-trip on every read/write.
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<double?> getSpeed(String mediaId) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString('$_prefix$mediaId');
      return raw == null ? null : double.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSpeed(String mediaId, double speed) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString('$_prefix$mediaId', speed.toString());
    } catch (_) {}
  }
}
