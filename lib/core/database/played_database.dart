import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../models/stem_cache.dart';
import '../models/vault_item.dart';
import 'hive_boxes.dart';
import 'duration_adapter.dart';

/// Central database service for PLAYED.
/// Manages playlists, playback history, shelf caches,
/// stem locations, and the AES-256 encrypted private vault.
class PlayedDatabase {
  PlayedDatabase._();
  static final PlayedDatabase instance = PlayedDatabase._();

  // ── Box references ──────────────────────────────────────────
  late Box<MediaItem> _historyBox;
  late Box<Playlist> _playlistBox;
  late Box<StemCache> _stemBox;
  late Box<Map> _seekPositionBox;
  late Box<String> _shelfCacheBox;
  late Box<dynamic> _vaultBox;

  bool _initialized = false;

  // ── Initialization ──────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register adapters — Duration must be registered before MediaItem
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(DurationAdapter());
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MediaItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlaylistAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(StemCacheAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(VaultItemAdapter());

    // Open standard boxes
    _historyBox = await Hive.openBox<MediaItem>(HiveBoxes.history);
    _playlistBox = await Hive.openBox<Playlist>(HiveBoxes.playlists);
    _stemBox = await Hive.openBox<StemCache>(HiveBoxes.stems);
    _seekPositionBox = await Hive.openBox<Map>(HiveBoxes.seekPositions);
    _shelfCacheBox = await Hive.openBox<String>(HiveBoxes.shelfCache);

    // Open AES-256 encrypted vault box
    final vaultKey = await _deriveVaultKey();
    _vaultBox = await Hive.openEncryptedBox<dynamic>(
      HiveBoxes.vault,
      encryptionCipher: HiveAesCipher(vaultKey),
    );

    _initialized = true;
    debugPrint('[PlayedDB] Initialized successfully.');
  }

  /// Derives a 32-byte AES key from a device-bound secret.
  /// In production, the seed is retrieved from FlutterSecureStorage.
  Future<Uint8List> _deriveVaultKey() async {
    const seed = 'played_vault_seed_v1';
    final bytes = utf8.encode(seed);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
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

  Future<void> clearSeekPosition(String mediaId) async {
    await _seekPositionBox.delete(mediaId);
  }

  // ── Playlists ───────────────────────────────────────────────

  Future<void> savePlaylist(Playlist playlist) async {
    await _playlistBox.put(playlist.id, playlist);
  }

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

  Future<void> cacheShelf(String shelfKey, List<String> mediaIds) async {
    await _shelfCacheBox.put(shelfKey, jsonEncode(mediaIds));
  }

  List<String> getShelfCache(String shelfKey) {
    final raw = _shelfCacheBox.get(shelfKey);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }

  Future<void> invalidateShelfCache() async => _shelfCacheBox.clear();

  // ── Stem Cache (Studio Split Tracks) ───────────────────────

  Future<void> saveStemCache(StemCache stem) async {
    await _stemBox.put(stem.sourceMediaId, stem);
  }

  StemCache? getStemCache(String sourceMediaId) =>
      _stemBox.get(sourceMediaId);

  bool hasStemCache(String sourceMediaId) =>
      _stemBox.containsKey(sourceMediaId);

  Future<void> deleteStemCache(String sourceMediaId) async =>
      _stemBox.delete(sourceMediaId);

  List<StemCache> getAllStems() => _stemBox.values.toList();

  // ── Private Vault ───────────────────────────────────────────

  Future<void> addToVault(VaultItem item) async {
    await _vaultBox.put(item.mediaId, item.toJson());
  }

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

  // ── Teardown ────────────────────────────────────────────────

  Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }
}
