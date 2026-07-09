import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'appwrite_service.dart';

/// Manages the user's Pro status.
///
/// Offline-first strategy:
///   1. In-memory cache (60s TTL) — zero disk/network reads within a session.
///   2. SharedPreferences — always written, works 100% offline.
///   3. Appwrite — only consulted when the device is online AND local
///      Pro has expired (handles reinstall / multi-device restore).
///
/// The app NEVER blocks on Appwrite. If offline, Pro status comes
/// entirely from SharedPreferences.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  static const _kProExpiry = 'pro_expiry_ms';

  int? _cachedExpiryMs;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(seconds: 60);

  bool get _isCacheValid =>
      _cachedExpiryMs != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl;

  Future<bool> isProActive() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. In-memory cache
    if (_isCacheValid) return now < _cachedExpiryMs!;

    final prefs = await SharedPreferences.getInstance();
    int expiry = prefs.getInt(_kProExpiry) ?? 0;

    // 2. Only hit Appwrite if local is expired AND device is online
    if (expiry <= now) {
      final online = await _isOnline();
      if (online) {
        final remoteExpiry = await AppwriteService.instance.fetchProExpiry();
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
    // Fire-and-forget Appwrite sync — offline is fine
    unawaited(AppwriteService.instance.saveProExpiry(expiry));
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
    unawaited(AppwriteService.instance.clearProExpiry());
  }

  /// Returns true only when the device has an active network connection.
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      // connectivity_plus always returns List<ConnectivityResult>.
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
