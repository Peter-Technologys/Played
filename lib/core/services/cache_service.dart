// lib/core/services/cache_service.dart
//
// Hive-backed TTL cache for API responses.
//
// TTL policy (per the performance requirements):
//   - Playlists:    5 minutes
//   - History:      2 minutes
//   - User profile: 10 minutes
//   - Custom TTL:   caller-specified
//
// Usage:
//   final cached = await CacheService.instance.get('playlists_$userId');
//   if (cached != null) return cached;
//   final fresh = await api.fetchPlaylists(userId);
//   await CacheService.instance.set('playlists_$userId', fresh,
//       ttl: CacheService.ttlPlaylists);
//   return fresh;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  // ── TTL constants ─────────────────────────────────────────────────────────

  static const Duration ttlPlaylists   = Duration(minutes: 5);
  static const Duration ttlHistory     = Duration(minutes: 2);
  static const Duration ttlUserProfile = Duration(minutes: 10);

  // ── Hive box ──────────────────────────────────────────────────────────────

  static const _boxName = 'otya_api_cache';
  Box<String>? _box;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    try {
      _box = await Hive.openBox<String>(_boxName);
      debugPrint('[CacheService] Initialized.');
    } catch (e) {
      debugPrint('[CacheService] init error: $e');
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<String>(_boxName);
      } catch (e2) {
        debugPrint('[CacheService] recovery also failed: $e2');
      }
    }
  }

  Box<String>? get _safeBox => (_box?.isOpen == true) ? _box : null;

  // ── Cache entry format ────────────────────────────────────────────────────
  //
  // Each entry is a JSON string:
  //   { "expiresAt": <epoch ms>, "data": <any JSON-encodable value> }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the cached value for [key] if it exists and has not expired.
  /// Returns null if the entry is missing or stale.
  Future<dynamic> get(String key) async {
    try {
      final raw = _safeBox?.get(key);
      if (raw == null) return null;
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = entry['expiresAt'] as int?;
      if (expiresAt == null) return null;
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        // Stale — delete and return null
        await _safeBox?.delete(key);
        return null;
      }
      return entry['data'];
    } catch (e) {
      debugPrint('[CacheService] get($key) error: $e');
      return null;
    }
  }

  /// Stores [value] under [key] with the given [ttl].
  Future<void> set(String key, dynamic value, {required Duration ttl}) async {
    try {
      final expiresAt =
          DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds;
      final entry = jsonEncode({'expiresAt': expiresAt, 'data': value});
      await _safeBox?.put(key, entry);
    } catch (e) {
      debugPrint('[CacheService] set($key) error: $e');
    }
  }

  /// Invalidates a single cache entry.
  Future<void> invalidate(String key) async {
    try {
      await _safeBox?.delete(key);
    } catch (_) {}
  }

  /// Invalidates all entries whose keys start with [prefix].
  Future<void> invalidatePrefix(String prefix) async {
    try {
      final box = _safeBox;
      if (box == null) return;
      final keys = box.keys
          .where((k) => k.toString().startsWith(prefix))
          .toList();
      await box.deleteAll(keys);
    } catch (e) {
      debugPrint('[CacheService] invalidatePrefix($prefix) error: $e');
    }
  }

  /// Clears all cached entries.
  Future<void> clear() async {
    try {
      await _safeBox?.clear();
    } catch (_) {}
  }

  /// Removes all expired entries (housekeeping — call periodically).
  Future<void> evictExpired() async {
    try {
      final box = _safeBox;
      if (box == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final toDelete = <dynamic>[];
      for (final key in box.keys) {
        try {
          final raw = box.get(key);
          if (raw == null) continue;
          final entry = jsonDecode(raw) as Map<String, dynamic>;
          final expiresAt = entry['expiresAt'] as int? ?? 0;
          if (now > expiresAt) toDelete.add(key);
        } catch (_) {
          toDelete.add(key); // corrupt entry — remove it
        }
      }
      if (toDelete.isNotEmpty) {
        await box.deleteAll(toDelete);
        debugPrint('[CacheService] Evicted ${toDelete.length} expired entries.');
      }
    } catch (e) {
      debugPrint('[CacheService] evictExpired error: $e');
    }
  }
}
