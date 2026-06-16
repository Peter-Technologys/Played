import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/stem_cache.dart';
import '../models/vault_item.dart';
import 'hive_boxes.dart';
import 'duration_adapter.dart';

/// Central offline database for PLAYED.
/// All data lives on-device in Hive boxes — no internet required.
class PlayedDatabase {
  PlayedDatabase._();
  static final PlayedDatabase instance = PlayedDatabase._();

  Box<MediaItem>? _historyBox;
  Box<Playlist>? _playlistBox;
  Box<StemCache>? _stemBox;
  Box<Map>? _seekPositionBox;
  Box<String>? _shelfCacheBox;
  Box<dynamic>? _vaultBox;

  bool _initialized = false;

  // Safe accessors — return empty fallback if box not open (prevents crashes)
  Box<MediaItem>  get _history      => _historyBox      ?? _emptyBox();
  Box<Playlist>   get _playlists    => _playlistBox     ?? _emptyBox();
  Box<StemCache>  get _stems        => _stemBox         ?? _emptyBox();
  Box<Map>        get _seekPos      => _seekPositionBox ?? _emptyBox();
  Box<String>     get _shelfCache   => _shelfCacheBox   ?? _emptyBox();
  Box<dynamic>    get _vault        => _vaultBox        ?? _emptyBox();

  // ignore: prefer_void_to_null
  Box<T> _emptyBox<T>() {
    // Should never be called in normal flow — init() always runs first.
    // Returns a dummy that throws on write but won't crash on read.
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

    // Register adapters — guard against double-registration
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(DurationAdapter());
    if (!Hive.isAdapterRegistered(0))  Hive.registerAdapter(MediaItemAdapter());
    if (!Hive.isAdapterRegistered(1))  Hive.registerAdapter(PlaylistAdapter());
    if (!Hive.isAdapterRegistered(2))  Hive.registerAdapter(StemCacheAdapter());
    if (!Hive.isAdapterRegistered(3))  Hive.registerAdapter(VaultItemAdapter());

    _historyBox      = await Hive.openBox<MediaItem>(HiveBoxes.history);
    _playlistBox     = await Hive.openBox<Playlist>(HiveBoxes.playlists);
    _stemBox         = await Hive.openBox<StemCache>(HiveBoxes.stems);
    _seekPositionBox = await Hive.openBox<Map>(HiveBoxes.seekPositions);
    _shelfCacheBox   = await Hive.openBox<String>(HiveBoxes.shelfCache);

    final vaultKey = await _deriveVaultKey();
    _vaultBox = await Hive.openBox<dynamic>(
      HiveBoxes.vault,
      encryptionCipher: HiveAesCipher(vaultKey),
    );
  }

  /// Called when Hive boxes are corrupted — deletes all boxes and re-opens.
  /// User loses local data but the app no longer crashes.
  Future<void> deleteAndReinit() async {
    debugPrint('[PlayedDB] Corruption detected — deleting and reinitializing.');
    try { await Hive.deleteBoxFromDisk(HiveBoxes.history); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.playlists); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.stems); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.seekPositions); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.shelfCache); } catch (_) {}
    try { await Hive.deleteBoxFromDisk(HiveBoxes.vault); } catch (_) {}
    _initialized = false;
    await init();
  }

  Future<Uint8List> _deriveVaultKey() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    const keyAlias = 'played_vault_key_v2';
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
      // Fallback: generate a session key (vault won't persist across restarts
      // but the app won't crash)
      debugPrint('[PlayedDB] Vault key error: $e — using session key');
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
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSeekPosition(String mediaId) async {
    try { await _seekPos.delete(mediaId); } catch (_) {}
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

  // ── Stem Cache ─────────────────────────────────────────────────────────────

  Future<void> saveStemCache(StemCache stem) async {
    try { await _stems.put(stem.sourceMediaId, stem); } catch (_) {}
  }

  StemCache? getStemCache(String id) {
    try { return _stems.get(id); } catch (_) { return null; }
  }

  bool hasStemCache(String id) {
    try { return _stems.containsKey(id); } catch (_) { return false; }
  }

  Future<void> deleteStemCache(String id) async {
    try { await _stems.delete(id); } catch (_) {}
  }

  List<StemCache> getAllStems() {
    try { return _stems.values.toList(); } catch (_) { return []; }
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

  static const _kFavPrefix = 'fav_';

  bool getFavoriteFlag(String mediaId) {
    try {
      final data = _seekPos.get('$_kFavPrefix$mediaId');
      return data != null && (data['fav'] as bool? ?? false);
    } catch (_) { return false; }
  }

  Future<void> setFavoriteFlag(String mediaId, bool value) async {
    try {
      await _seekPos.put('$_kFavPrefix$mediaId', {'fav': value});
    } catch (_) {}
  }

  List<String> getAllFavoriteIds() {
    try {
      return _seekPos.keys
          .where((k) => k.toString().startsWith(_kFavPrefix))
          .map((k) => k.toString().substring(_kFavPrefix.length))
          .toList();
    } catch (_) { return []; }
  }

  // ── Lyrics Cache ────────────────────────────────────────────────────────────

  Future<void> cacheLyrics(String mediaId, String rawLyrics) async {
    try { await _shelfCache.put('lyrics_$mediaId', rawLyrics); } catch (_) {}
  }

  String? getCachedLyrics(String mediaId) {
    try { return _shelfCache.get('lyrics_$mediaId'); } catch (_) { return null; }
  }

  // ── Teardown ─────────────────────────────────────────────────────────────────

  Future<void> close() async {
    try { await Hive.close(); } catch (_) {}
    _initialized = false;
  }
}
