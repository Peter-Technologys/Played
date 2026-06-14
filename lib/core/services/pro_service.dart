import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_pro_service.dart';

/// Manages the user's Pro status.
/// Pro is granted for 30 minutes after watching a rewarded ad.
///
/// Storage strategy (layered):
///   1. In-memory cache — avoids repeated disk/network reads within a session.
///   2. SharedPreferences — always written, works offline.
///   3. Firestore — written when online; read on first launch to restore
///      Pro across reinstalls / devices for signed-in users.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  static const _kProExpiry = 'pro_expiry_ms';

  // In-memory cache to avoid hammering SharedPreferences / Firestore
  int? _cachedExpiryMs;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(seconds: 60);

  bool get _isCacheValid =>
      _cachedExpiryMs != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl;

  /// Returns true if the user currently has active Pro access.
  Future<bool> isProActive() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Use in-memory cache if fresh
    if (_isCacheValid) return now < _cachedExpiryMs!;

    final prefs = await SharedPreferences.getInstance();
    int expiry = prefs.getInt(_kProExpiry) ?? 0;

    // 2. If local says expired, check Firestore once (handles reinstall)
    if (expiry <= now) {
      final remoteExpiry = await FirestoreProService.instance.fetchProExpiry();
      if (remoteExpiry > expiry) {
        expiry = remoteExpiry;
        await prefs.setInt(_kProExpiry, expiry);
      }
    }

    _cachedExpiryMs = expiry;
    _cacheTime = DateTime.now();
    return now < expiry;
  }

  /// Grants Pro access for [minutes] minutes (default 30).
  Future<void> grantPro({int minutes = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    await prefs.setInt(_kProExpiry, expiry);
    _cachedExpiryMs = expiry;
    _cacheTime = DateTime.now();
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

  /// Revokes Pro access immediately.
  Future<void> revokePro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProExpiry);
    _cachedExpiryMs = 0;
    _cacheTime = DateTime.now();
    FirestoreProService.instance.clearProExpiry();
  }
}
