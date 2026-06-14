import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_pro_service.dart';

/// Manages the user's Pro status.
/// Pro is granted for 30 minutes after watching a rewarded ad.
///
/// Storage strategy (layered):
///   1. SharedPreferences — always written, works offline.
///   2. Firestore — written when online; read on first launch to restore
///      Pro across reinstalls / devices for signed-in users.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  static const _kProExpiry = 'pro_expiry_ms';

  /// Returns true if the user currently has active Pro access.
  /// Checks local cache first; falls back to Firestore on first run.
  Future<bool> isProActive() async {
    final prefs = await SharedPreferences.getInstance();
    int expiry = prefs.getInt(_kProExpiry) ?? 0;

    // If local says expired, check Firestore once (handles reinstall case)
    if (expiry <= DateTime.now().millisecondsSinceEpoch) {
      final remoteExpiry =
          await FirestoreProService.instance.fetchProExpiry();
      if (remoteExpiry > expiry) {
        expiry = remoteExpiry;
        await prefs.setInt(_kProExpiry, expiry);
      }
    }

    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  /// Grants Pro access for [minutes] minutes (default 30).
  /// Called after a rewarded ad is successfully watched.
  Future<void> grantPro({int minutes = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    await prefs.setInt(_kProExpiry, expiry);
    // Sync to Firestore (fire-and-forget — offline is fine)
    FirestoreProService.instance.saveProExpiry(expiry);
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
    FirestoreProService.instance.clearProExpiry();
  }
}
