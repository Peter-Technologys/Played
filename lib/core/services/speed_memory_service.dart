import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last playback speed used for each media item.
/// Key: 'speed_<mediaId>'  Value: double as string
class SpeedMemoryService {
  SpeedMemoryService._();
  static final SpeedMemoryService instance = SpeedMemoryService._();

  static const _prefix = 'speed_';

  Future<double?> getSpeed(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$mediaId');
      if (raw == null) return null;
      return double.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSpeed(String mediaId, double speed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$mediaId', speed.toString());
    } catch (_) {}
  }
}
