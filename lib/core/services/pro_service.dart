import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's Pro status.
/// Pro is granted for 24 hours after watching a rewarded ad.
/// Persisted in SharedPreferences so it survives app restarts.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  static const _kProExpiry = 'pro_expiry_ms';

  /// Returns true if the user currently has active Pro access.
  Future<bool> isProActive() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt(_kProExpiry) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  /// Grants Pro access for [hours] hours (default 24).
  /// Called after a rewarded ad is successfully watched.
  Future<void> grantPro({int hours = 24}) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now()
        .add(Duration(hours: hours))
        .millisecondsSinceEpoch;
    await prefs.setInt(_kProExpiry, expiry);
  }

  /// Returns how much Pro time is remaining, or Duration.zero if expired.
  Future<Duration> remainingProTime() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt(_kProExpiry) ?? 0;
    final remaining = expiry - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  /// Revokes Pro access immediately (for testing).
  Future<void> revokePro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProExpiry);
  }
}
