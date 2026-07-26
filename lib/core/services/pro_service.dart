import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloudflare_service.dart';
import '../utils/connectivity_utils.dart';

/// Manages the user's Pro status.
///
/// Offline-first strategy:
///   1. In-memory cache (60s TTL) — zero disk/network reads within a session.
///   2. SharedPreferences — always written, works 100% offline.
///   3. Cloudflare Worker — only consulted when the device is online AND local
///      Pro has expired (handles reinstall / multi-device restore).
///
/// The app NEVER blocks on the network. If offline, Pro status comes
/// entirely from SharedPreferences.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  static const _kProExpiry = 'pro_expiry_ms';
  // userId stored by Google Sign-In flow; Cloudflare ignores empty string gracefully.
  static const _kUserId = 'otya_user_id';

  int? _cachedExpiryMs;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(seconds: 60);

  bool get _isCacheValid =>
      _cachedExpiryMs != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl;

  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserId) ?? '';
  }

  Future<bool> isProActive() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. In-memory cache
    if (_isCacheValid) return now < _cachedExpiryMs!;

    final prefs = await SharedPreferences.getInstance();
    int expiry = prefs.getInt(_kProExpiry) ?? 0;

    // 2. Only hit Cloudflare if local is expired AND device is online
    if (expiry <= now) {
      final online = await isOnline();
      if (online) {
        final userId = await _getUserId();
        final remoteExpiry =
            await CloudflareService.instance.fetchProExpiry(userId);
        if (remoteExpiry > expiry) {
          expiry = remoteExpiry;
          await prefs.setInt(_kProExpiry, expiry);
        }
      }
    }

    _cachedExpiryMs = expiry;
    _cacheTime = DateTime.now();
    return now < expiry;
  }

  Future<void> grantPro({int minutes = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    await prefs.setInt(_kProExpiry, expiry);
    _cachedExpiryMs = expiry;
    _cacheTime = DateTime.now();
    // Fire-and-forget Cloudflare sync — offline is fine
    final userId = await _getUserId();
    unawaited(CloudflareService.instance.saveProExpiry(userId, expiry));
  }

  Future<Duration> remainingProTime() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt(_kProExpiry) ?? 0;
    final remaining = expiry - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  Future<void> revokePro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProExpiry);
    _cachedExpiryMs = 0;
    _cacheTime = DateTime.now();
    final userId = await _getUserId();
    unawaited(CloudflareService.instance.saveProExpiry(userId, 0));
  }
}
