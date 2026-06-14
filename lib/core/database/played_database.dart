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
/// The encrypted vault uses AES-256 with a key stored in
/// FlutterSecureStorage (Android Keystore-backed).
class PlayedDatabase {
  PlayedDatabase._();
  static final PlayedDatabase instance = PlayedDatabase._();

  late Box<MediaItem> _historyBox;
  late Box<Playlist> _playlistBox;
  late Box<StemCache> _stemBox;
  late Box<Map> _seekPositionBox;
  late Box<String> _shelfCacheBox;
  late Box<dynamic> _vaultBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register adapters — order matters: Duration before MediaItem
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

    // AES-256 encrypted vault — key is generated once and stored in
    // Android Keystore via FlutterSecureStorage, never leaves the device
    final vaultKey = await _deriveVaultKey();
    _vaultBox = await Hive.openBox<dynamic>(
      HiveBoxes.vault,
      encryptionCipher: HiveAesCipher(vaultKey),
    );

    _initialized = true;
    debugPrint('[PlayedDB] Initialized successfully.');
  }

  /// Generates (on first install) or retrieves a cryptographically secure
  /// 32-byte AES key from FlutterSecureStorage.
  ///
  /// FIX: The previous implementation used
  ///   DateTime.now().microsecondsSinceEpoch % 256
  /// in a tight loop which produced near-identical byte values (very low
  /// entropy) and could generate a key that fails HiveAesCipher validation,
  /// crashing the app before any UI appeared on first install.
  Future<Uint8List> _deriveVaultKey() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    const keyAlias = 'played_vault_key_v2';
    String? existing = await storage.read(key: keyAlias);
    if (existing == null) {
      // Cryptographically secure random 32-byte key
      final rng = Random.secure();
      final key = Uint8List.fromList(
          List<int>.generate(32, (_) => rng.nextInt(256)));
      existing = base64Encode(key);
      await storage.write(key: keyAlias, value: existing);
    }
    return Uint8List.fromList(base64Decode(existing));
  }

  // ── Playback History ────────────────────────────────────────

  Future<void> recordPlay(MediaItem item) async {
    item.lastPlayedAt = DateTime.now();
    await _historyBox.put(item.id, item);
  }

  List<MediaItem> getRecentlyPlayed({int limit = 30}) {
    final items = _historyBox.values.toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return items.take(limit).toList();
  }

  Future<void> clearHistory() async => _historyBox.clear();

  // ── Seek Position (Auto-Resume) ─────────────────────────────

  Future<void> saveSeekPosition(String mediaId, Duration position) async {
    await _seekPositionBox.put(mediaId, {
      'ms': position.inMilliseconds,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  Duration? getSeekPosition(String mediaId) {
    final data = _seekPositionBox.get(mediaId);
    if (data == null) return null;
    return Duration(milliseconds: data['ms'] as int);
  }

  Future<void> clearSeekPosition(String mediaId) async =>
      _seekPositionBox.delete(mediaId);

  // ── Playlists ───────────────────────────────────────────────

  Future<void> savePlaylist(Playlist playlist) async =>
      _playlistBox.put(playlist.id, playlist);

  List<Playlist> getAllPlaylists() => _playlistBox.values.toList();

  Playlist? getPlaylist(String id) => _playlistBox.get(id);

  Future<void> addToPlaylist(String playlistId, MediaItem item) async {
    final playlist = _playlistBox.get(playlistId);
    if (playlist == null) return;
    if (!playlist.mediaIds.contains(item.id)) {
      playlist.mediaIds.add(item.id);
      await playlist.save();
    }
  }

  Future<void> deletePlaylist(String id) async => _playlistBox.delete(id);

  // ── Dynamic Shelf Cache ─────────────────────────────────────

  Future<void> cacheShelf(String shelfKey, List<String> mediaIds) async =>
      _shelfCacheBox.put(shelfKey, jsonEncode(mediaIds));

  List<String> getShelfCache(String shelfKey) {
    final raw = _shelfCacheBox.get(shelfKey);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  Future<void> invalidateShelfCache() async => _shelfCacheBox.clear();

  // ── Stem Cache ──────────────────────────────────────────────

  Future<void> saveStemCache(StemCache stem) async =>
      _stemBox.put(stem.sourceMediaId, stem);

  StemCache? getStemCache(String sourceMediaId) => _stemBox.get(sourceMediaId);
  bool hasStemCache(String sourceMediaId) => _stemBox.containsKey(sourceMediaId);
  Future<void> deleteStemCache(String sourceMediaId) async =>
      _stemBox.delete(sourceMediaId);
  List<StemCache> getAllStems() => _stemBox.values.toList();

  // ── Private Vault ───────────────────────────────────────────

  Future<void> addToVault(VaultItem item) async =>
      _vaultBox.put(item.mediaId, item.toJson());

  Future<VaultItem?> getVaultItem(String mediaId) async {
    final raw = _vaultBox.get(mediaId);
    if (raw == null) return null;
    return VaultItem.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<VaultItem>> getAllVaultItems() async {
    return _vaultBox.values
        .map((raw) =>
            VaultItem.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Future<void> removeFromVault(String mediaId) async =>
      _vaultBox.delete(mediaId);

  bool isInVault(String mediaId) => _vaultBox.containsKey(mediaId);

  // ── Favorites ────────────────────────────────────────────────

  static const _kFavPrefix = 'fav_';

  bool getFavoriteFlag(String mediaId) {
    final data = _seekPositionBox.get('$_kFavPrefix$mediaId');
    return data != null && (data['fav'] as bool? ?? false);
  }

  Future<void> setFavoriteFlag(String mediaId, bool value) async =>
      _seekPositionBox.put('$_kFavPrefix$mediaId', {'fav': value});

  List<String> getAllFavoriteIds() {
    return _seekPositionBox.keys
        .where((k) => k.toString().startsWith(_kFavPrefix))
        .map((k) => k.toString().substring(_kFavPrefix.length))
        .toList();
  }

  // ── Lyrics Cache ──────────────────────────────────────────────────────

  Future<void> cacheLyrics(String mediaId, String rawLyrics) async =>
      _shelfCacheBox.put('lyrics_$mediaId', rawLyrics);

  String? getCachedLyrics(String mediaId) =>
      _shelfCacheBox.get('lyrics_$mediaId');

  // ── Teardown ──────────────────────────────────────────────────────

  Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }
}
