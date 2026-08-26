import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../database/otya_database.dart';
import '../models/playlist.dart';
import '../utils/connectivity_utils.dart';
import 'app_sync_service.dart';
import 'api_signer.dart';
import 'http_client.dart';

/// Cloud sync client for playlists, history and Pro status.
/// Network failures are non-fatal and local data remains authoritative.
class CloudflareService {
  CloudflareService._();
  static final CloudflareService instance = CloudflareService._();

  static const Duration _timeout = Duration(seconds: 12);
  static const String _kPendingBackupUserId = 'otya_pending_backup_user_id';
  static bool _backupInProgress = false;

  http.Client get _client => AppHttpClient.instance.client;

  Future<void> _queuePendingBackup(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingBackupUserId, userId);
    } catch (e) {
      debugPrint('[Cloudflare] queue failed: $e');
    }
  }

  /// Flushes an offline backup without calling backupAll(), avoiding recursive
  /// backupPlaylists -> flush -> backupAll -> backupPlaylists recursion.
  Future<void> _flushPendingBackup() async {
    if (_backupInProgress) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_kPendingBackupUserId);
      if (userId == null || !await isOnline()) return;
      _backupInProgress = true;
      final ok = await _backupData(userId);
      if (ok) await prefs.remove(_kPendingBackupUserId);
    } catch (e) {
      debugPrint('[Cloudflare] pending backup failed: $e');
    } finally {
      _backupInProgress = false;
    }
  }

  Map<String, String> _getHeaders(String path) =>
      ApiSigner.signedHeaders(method: 'GET', path: path);

  Map<String, String> _postHeaders(String path) => {
    ...ApiSigner.signedHeaders(method: 'POST', path: path),
    'Content-Type': 'application/json',
  };

  Future<bool> backupPlaylists(String userId) async {
    if (!await isOnline()) {
      await _queuePendingBackup(userId);
      return false;
    }
    if (_backupInProgress) return false;
    await _flushPendingBackup();
    try {
      _backupInProgress = true;
      return await _backupPlaylistsOnly(userId);
    } finally {
      _backupInProgress = false;
    }
  }

  Future<bool> _backupPlaylistsOnly(String userId) async {
    final playlists = OtyaDatabase.instance.getAllPlaylists();
    int synced = 0;
    const batchSize = 5;
    const path = '/api/playlists';
    for (var i = 0; i < playlists.length; i += batchSize) {
      final batch = playlists.skip(i).take(batchSize);
      final results = await Future.wait(batch.map((pl) async {
        try {
          final res = await _client.post(
            Uri.parse(Environment.apiPlaylistsUrl),
            headers: _postHeaders(path),
            body: jsonEncode({
              'id': '${userId}_${pl.id}',
              'user_id': userId,
              'name': pl.name,
              'media_ids': jsonEncode(pl.mediaIds),
            }),
          ).timeout(_timeout);
          return res.statusCode == 200;
        } catch (e) {
          debugPrint('[Cloudflare] playlist upload failed: $e');
          return false;
        }
      }));
      synced += results.where((ok) => ok).length;
    }
    return synced == playlists.length;
  }

  Future<int> restorePlaylists(String userId) async {
    try {
      const path = '/api/playlists';
      final res = await _client.get(
        Uri.parse('${Environment.apiPlaylistsUrl}?user_id=${Uri.encodeQueryComponent(userId)}'),
        headers: _getHeaders(path),
      ).timeout(_timeout);
      if (res.statusCode != 200) return -1;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['playlists'] as List<dynamic>?) ?? [];
      int restored = 0;
      for (final raw in list) {
        final map = raw as Map<String, dynamic>;
        final id = map['id']?.toString();
        if (id == null) continue;
        final mediaRaw = map['media_ids']?.toString() ?? '[]';
        List<String> mediaIds;
        try {
          mediaIds = List<String>.from(jsonDecode(mediaRaw) as List);
        } catch (_) {
          mediaIds = const [];
        }
        final playlist = Playlist(
          id: id.replaceFirst('${userId}_', ''),
          name: map['name']?.toString() ?? 'Playlist',
          mediaIds: mediaIds,
          createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await OtyaDatabase.instance.savePlaylist(playlist);
        restored++;
      }
      return restored;
    } catch (e) {
      debugPrint('[Cloudflare] restorePlaylists failed: $e');
      return -1;
    }
  }

  Future<void> backupHistory(String userId) async {
    if (!await isOnline()) {
      await _queuePendingBackup(userId);
      return;
    }
    if (_backupInProgress) return;
    try {
      _backupInProgress = true;
      await _backupHistoryOnly(userId);
    } finally {
      _backupInProgress = false;
    }
  }

  Future<bool> _backupHistoryOnly(String userId) async {
    final history = OtyaDatabase.instance.getRecentlyPlayed(limit: 200);
    int synced = 0;
    const batchSize = 10;
    const path = '/api/history';
    for (var i = 0; i < history.length; i += batchSize) {
      final batch = history.skip(i).take(batchSize);
      final results = await Future.wait(batch.map((item) async {
        try {
          final res = await _client.post(
            Uri.parse(Environment.apiHistoryUrl),
            headers: _postHeaders(path),
            body: jsonEncode({
              'id': '${userId}_${item.id}',
              'user_id': userId,
              'title': item.title,
              'artist': item.artist ?? '',
              'file_path': item.filePath,
              'is_video': item.isVideo ? '1' : '0',
              'last_played_at': item.lastPlayedAt?.toIso8601String() ?? '',
            }),
          ).timeout(_timeout);
          return res.statusCode == 200;
        } catch (_) {
          return false;
        }
      }));
      synced += results.where((ok) => ok).length;
    }
    return synced == history.length;
  }

  Future<void> saveProExpiry(String userId, int expiryMs) async {
    if (!await isOnline()) return;
    try {
      const path = '/api/pro';
      await _client.post(
        Uri.parse(Environment.apiProUrl),
        headers: _postHeaders(path),
        body: jsonEncode({'user_id': userId, 'expiry_ms': expiryMs}),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[Cloudflare] saveProExpiry failed: $e');
    }
  }

  Future<int> fetchProExpiry(String userId) async {
    if (!await isOnline()) return 0;
    try {
      const path = '/api/pro';
      final res = await _client.get(
        Uri.parse('${Environment.apiProUrl}?user_id=${Uri.encodeQueryComponent(userId)}'),
        headers: _getHeaders(path),
      ).timeout(_timeout);
      if (res.statusCode != 200) return 0;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['expiry_ms'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[Cloudflare] fetchProExpiry failed: $e');
      return 0;
    }
  }

  Future<bool> _backupData(String userId) async {
    final playlistsOk = await _backupPlaylistsOnly(userId);
    final historyOk = await _backupHistoryOnly(userId);
    if (playlistsOk && historyOk) {
      unawaited(AppSyncService.instance.syncOnlineIfNeeded(null));
      return true;
    }
    return false;
  }

  Future<bool> backupAll(String userId) async {
    if (!await isOnline() || _backupInProgress) {
      await _queuePendingBackup(userId);
      return false;
    }
    _backupInProgress = true;
    try {
      return await _backupData(userId);
    } catch (e) {
      debugPrint('[Cloudflare] backupAll failed: $e');
      await _queuePendingBackup(userId);
      return false;
    } finally {
      _backupInProgress = false;
    }
  }
}
