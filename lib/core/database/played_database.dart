import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/vault_item.dart';
import 'hive_boxes.dart';
import 'duration_adapter.dart';

/// Central offline database for OTYA Player.
/// All data lives on-device in Hive boxes — no internet required.
class PlayedDatabase {
  PlayedDatabase._();
  static final PlayedDatabase instance = PlayedDatabase._();

  Box<MediaItem>? _historyBox;
  Box<Playlist>?  _playlistBox;
  Box<Map>?       _seekPositionBox;
  Box<String>?    _shelfCacheBox;
  Box<dynamic>?   _vaultBox;

  bool _initialized = false;

  Box<MediaItem> get _history    => _historyBox      ?? _emptyBox();
  Box<Playlist>  get _playlists  => _playlistBox     ?? _emptyBox();
  Box<Map>       get _seekPos    => _seekPositionBox ?? _emptyBox();
  Box<String>    get _shelfCache => _shelfCacheBox   ?? _emptyBox();
  Box<dynamic>   get _vault      => _vaultBox        ?? _emptyBox();

  Box<T> _emptyBox<T>() {
    throw StateError('[PlayedDB] Database not initialized. Call init() first.');
  }

  Future<void> init() async {
    if (_initialized) return;
    await _openBoxes();
    _initialized = true;
    debugPrint('[PlayedDB] Initialized successfully.');
  }

  Future<void> _openBoxes() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(DurationAdapter());
    if (!Hive.isAdapterRegistered(0))  Hive.registerAdapter(MediaItemAdapter());
    if (!Hive.isAdapterRegistered(1))  Hive.registerAdapter(PlaylistAdapter());
    if (!Hive.isAdapterRegistered(3))  Hive.registerAdapter(VaultItemAdapter());

    _historyBox      = await Hive.openBox<MediaItem>(HiveBoxes.history);
    _playlistBox     = await Hive.openBox<Playlist>(HiveBoxes.playlists);
    _seekPositionBox = await Hive.openBox<Map>(HiveBoxes.seekPositions);
    _shelfCacheBox   = await Hive.openBox<String>(HiveBoxes.shelfCache);

    final vaultKey = await _deriveVaultKey();
    _vaultBox = await Hive.openBox<dynamic>(
      HiveBoxes.vault,
      encryptionCipher: HiveAesCipher(vaultKey),
    );
  }

  Future<void> deleteAndReinit() async {
    debugPrint('[PlayedDB] Corruption detected — deleting and reinitializing.');
    try { await Hive.deleteBoxFromDisk(HiveBoxes.history); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.playlists); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.seekPositions); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.shelfCache); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.vault); } catch (_) {}
    _initialized = false;
    await init();
  }

  // Platform channel to retrieve Settings.Secure.ANDROID_ID from Kotlin.
  // Used as a deterministic fallback seed when FlutterSecureStorage fails.
  static const _kDeviceIdChannel = MethodChannel('com.otyaplayer.app/device_id');

  Future<Uint8List> _deriveVaultKey() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    const keyAlias = 'otya_vault_key_v1';
    try {
      String? existing = await storage.read(key: keyAlias);
      if (existing == null) {
        final rng = Random.secure();
        final key = Uint8List.fromList(
            List<int>.generate(32, (_) => rng.nextInt(256)));
        existing = base64Encode(key);
        await storage.write(key: keyAlias, value: existing);
      }
      return Uint8List.fromList(base64Decode(existing));
    } catch (e) {
      // Fix #12: if FlutterSecureStorage fails (no secure enclave, device
      // policy, etc.), derive a deterministic key from ANDROID_ID instead of
      // a random session key. A random key is lost on restart, making all
      // vault data permanently unreadable.
      debugPrint('[PlayedDB] Vault key error: $e — falling back to ANDROID_ID derivation');
      return _deriveKeyFromAndroidId();
    }
  }

  /// Derives a deterministic 32-byte key from the device's ANDROID_ID.
  /// ANDROID_ID is stable across reboots (changes only on factory reset),
  /// so the vault remains readable after app restarts even without secure storage.
  Future<Uint8List> _deriveKeyFromAndroidId() async {
    try {
      final androidId = await _kDeviceIdChannel.invokeMethod<String>('getAndroidId') ?? '';
      if (androidId.isNotEmpty) {
        // Stretch the ANDROID_ID into 32 bytes using a simple PBKDF-like
        // approach: repeat + XOR with a fixed salt to fill 32 bytes.
        const salt = 'otya_vault_v1_salt';
        final combined = '$androidId:$salt';
        final bytes = combined.codeUnits;
        final key = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          // Fix: parenthesise correctly so the 0xFF mask applies to the full
          // expression, not just the constant 13 (operator precedence bug).
          key[i] = bytes[i % bytes.length] ^ ((i * 37 + 13) & 0xFF);
        }
        debugPrint('[PlayedDB] Vault key derived from ANDROID_ID.');
        return key;
      }
    } catch (e) {
      debugPrint('[PlayedDB] ANDROID_ID fallback failed: $e');
    }
    // Absolute last resort: generate a random UUID seed once and persist it
    // in SharedPreferences so the key is unique per device and stable across
    // restarts (unlike a bare fixed constant which is identical for all users).
    debugPrint('[PlayedDB] Using SharedPreferences-seeded vault key (last resort).');
    try {
      final prefs = await SharedPreferences.getInstance();
      const prefKey = 'otya_vault_fallback_seed';
      String? seed = prefs.getString(prefKey);
      if (seed == null) {
        seed = const Uuid().v4();
        await prefs.setString(prefKey, seed);
      }
      final bytes = seed.codeUnits;
      final key = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        key[i] = bytes[i % bytes.length] ^ ((i * 53 + 7) & 0xFF);
      }
      return key;
    } catch (e) {
      debugPrint('[PlayedDB] SharedPreferences fallback failed: $e — using random session key');
      // True last resort: random key (vault data lost on restart, but avoids crash)
      final rng = Random.secure();
      return Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
    }
  }

  // ── Playback History ──────────────────────────────────────────────────────

  Future<void> recordPlay(MediaItem item) async {
    try {
      item.lastPlayedAt = DateTime.now();
      await _history.put(item.id, item);
    } catch (e) {
      debugPrint('[PlayedDB] recordPlay error: $e');
    }
  }

  /// Seeds a MediaItem into history WITHOUT updating lastPlayedAt.
  /// Used by MediaLibraryNotifier._writeBackToHive() to populate the
  /// Phase 1b seed without corrupting play history timestamps.
  Future<void> seedLibraryItem(MediaItem item) async {
    try {
      // Only write if not already in history (preserve existing lastPlayedAt)
      if (!_history.containsKey(item.id)) {
        await _history.put(item.id, item);
      }
    } catch (e) {
      debugPrint('[PlayedDB] seedLibraryItem error: $e');
    }
  }

  List<MediaItem> getRecentlyPlayed({int limit = 30}) {
    try {
      final items = _history.values.toList()
        ..sort((a, b) {
          final aTime = a.lastPlayedAt ?? DateTime(0);
          final bTime = b.lastPlayedAt ?? DateTime(0);
          return bTime.compareTo(aTime);
        });
      return items.take(limit).toList();
    } catch (e) {
      debugPrint('[PlayedDB] getRecentlyPlayed error: $e');
      return [];
    }
  }

  Future<void> clearHistory() async {
    try { await _history.clear(); } catch (_) {}
  }

  // ── Seek Position ────────────────────────────────────────────────────────

  Future<void> saveSeekPosition(String mediaId, Duration position) async {
    try {
      await _seekPos.put(mediaId, {
        'ms': position.inMilliseconds,
        'savedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Duration? getSeekPosition(String mediaId) {
    try {
      final data = _seekPos.get(mediaId);
      if (data == null) return null;
      return Duration(milliseconds: (data['ms'] as num).toInt());
    } catch (_) { return null; }
  }

  Future<void> clearSeekPosition(String mediaId) async {
    try { await _seekPos.delete(mediaId); } catch (_) {}
  }

  /// Clears ALL saved seek positions — used by the Storage Cleaner tool.
  Future<void> clearAllSeekPositions() async {
    try { await _seekPos.clear(); } catch (_) {}
  }

  // ── Playlists ──────────────────────────────────────────────────────────────

  Future<void> savePlaylist(Playlist playlist) async {
    try { await _playlists.put(playlist.id, playlist); } catch (_) {}
  }

  List<Playlist> getAllPlaylists() {
    try { return _playlists.values.toList(); } catch (_) { return []; }
  }

  Playlist? getPlaylist(String id) {
    try { return _playlists.get(id); } catch (_) { return null; }
  }

  Future<void> addToPlaylist(String playlistId, MediaItem item) async {
    try {
      final playlist = _playlists.get(playlistId);
      if (playlist == null) return;
      if (!playlist.mediaIds.contains(item.id)) {
        playlist.mediaIds.add(item.id);
        await playlist.save();
      }
    } catch (_) {}
  }

  Future<void> deletePlaylist(String id) async {
    try { await _playlists.delete(id); } catch (_) {}
  }

  // ── Shelf Cache ─────────────────────────────────────────────────────────────

  Future<void> cacheShelf(String shelfKey, List<String> mediaIds) async {
    try { await _shelfCache.put(shelfKey, jsonEncode(mediaIds)); } catch (_) {}
  }

  List<String> getShelfCache(String shelfKey) {
    try {
      final raw = _shelfCache.get(shelfKey);
      if (raw == null) return [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) { return []; }
  }

  Future<void> invalidateShelfCache() async {
    try { await _shelfCache.clear(); } catch (_) {}
  }

  // ── Vault ───────────────────────────────────────────────────────────────────

  Future<void> addToVault(VaultItem item) async {
    try { await _vault.put(item.mediaId, item.toJson()); } catch (_) {}
  }

  Future<VaultItem?> getVaultItem(String mediaId) async {
    try {
      final raw = _vault.get(mediaId);
      if (raw == null) return null;
      return VaultItem.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) { return null; }
  }

  Future<List<VaultItem>> getAllVaultItems() async {
    try {
      return _vault.values
          .map((raw) =>
              VaultItem.fromJson(Map<String, dynamic>.from(raw as Map)))
          .toList();
    } catch (_) { return []; }
  }

  Future<void> removeFromVault(String mediaId) async {
    try { await _vault.delete(mediaId); } catch (_) {}
  }

  bool isInVault(String mediaId) {
    try { return _vault.containsKey(mediaId); } catch (_) { return false; }
  }

  // ── Favorites ───────────────────────────────────────────────────────────────
  // Stored in _shelfCacheBox (Box<String>) to avoid polluting the seek-position
  // box (Box<Map>) with non-seek data and risking type errors on clearance.

  static const _kFavPrefix = 'fav_';

  bool getFavoriteFlag(String mediaId) {
    try {
      final val = _shelfCache.get('$_kFavPrefix$mediaId');
      return val == '1';
    } catch (_) { return false; }
  }

  Future<void> setFavoriteFlag(String mediaId, bool value) async {
    try {
      await _shelfCache.put('$_kFavPrefix$mediaId', value ? '1' : '0');
    } catch (_) {}
  }

  List<String> getAllFavoriteIds() {
    try {
      return _shelfCache.keys
          .where((k) => k.toString().startsWith(_kFavPrefix))
          .map((k) => k.toString().substring(_kFavPrefix.length))
          .toList();
    } catch (_) { return []; }
  }

  /// Returns all MediaItems that are marked as favorites, filtered from the
  /// provided [allItems] list (since favorites are stored as IDs only).
  List<MediaItem> getFavoriteItems(List<MediaItem> allItems) {
    try {
      final ids = getAllFavoriteIds().toSet();
      return allItems.where((item) => ids.contains(item.id)).toList();
    } catch (_) { return []; }
  }

  /// Returns items added within the last [days] days, sorted newest first.
  List<MediaItem> getRecentlyAddedItems(List<MediaItem> allItems, {int days = 7}) {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      return allItems
          .where((item) => item.addedAt.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (_) { return []; }
  }

  /// Returns playback history sorted by most recently played, with timestamps.
  List<MediaItem> getPlaybackHistory({int limit = 200}) {
    return getRecentlyPlayed(limit: limit);
  }

  Future<void> clearPlaybackHistory() async {
    await clearHistory();
  }

  // ── Lyrics Cache ────────────────────────────────────────────────────────────
  //
  // BUG 8: _shelfCacheBox stores three distinct namespaces. Key prefixes are
  // documented here as static consts to prevent future collision:
  //   _kFavPrefix   = 'fav_'    — favorite flags
  //   _kLyricsPrefix = 'lyrics_' — cached lyrics
  //   (no prefix)               — shelf/playlist cache (plain shelfKey strings)
  //
  // IMPORTANT: Never use a plain key that starts with 'fav_' or 'lyrics_'.

  static const _kLyricsPrefix = 'lyrics_';

  Future<void> cacheLyrics(String mediaId, String rawLyrics) async {
    try { await _shelfCache.put('$_kLyricsPrefix$mediaId', rawLyrics); } catch (_) {}
  }

  String? getCachedLyrics(String mediaId) {
    try { return _shelfCache.get('$_kLyricsPrefix$mediaId'); } catch (_) { return null; }
  }

  // ── Teardown ─────────────────────────────────────────────────────────────────

  Future<void> close() async {
    try { await Hive.close(); } catch (_) {}
    _historyBox      = null;
    _playlistBox     = null;
    _seekPositionBox = null;
    _shelfCacheBox   = null;
    _vaultBox        = null;
    _initialized     = false;
  }
}
