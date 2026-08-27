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
import 'auth_service.dart';
import 'http_client.dart';
import 'remote_control_service.dart';

/// Cloud sync client for playlists, history and Pro status.
///
/// Local media remains authoritative and network failures are non-fatal.
/// Every protected request uses the short-lived JWT issued by OTYA Auth;
/// user ownership is taken from the authenticated profile, never a caller-
/// supplied arbitrary identifier.
class CloudflareService {
  CloudflareService._();
  static final CloudflareService instance = CloudflareService._();

  static const String _kPendingBackupUserId = 'otya_pending_backup_user_id';
  static bool _backupInProgress = false;

  http.Client get _client => AppHttpClient.instance.client;

  Duration get _timeout {
    final raw = RemoteControlService.instance.runtime['apiTimeoutSeconds'];
    final seconds = raw is num ? raw.toInt() : int.tryParse('$raw');
    return Duration(seconds: (seconds ?? 12).clamp(4, 30));
  }

  Future<({String token, String userId})?> _authContext() async {
    final token = await AuthService.instance.getValidToken();
    final userId = AuthService.instance.userId;
    if (token == null || userId == null || userId.isEmpty) return null;
    return (token: token, userId: userId);
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Authorization': 'Bearer $token',
        if (json) 'Content-Type': 'application/json',
      };

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
      final pendingUserId = prefs.getString(_kPendingBackupUserId);
      if (pendingUserId == null || !await isOnline()) return;
      final auth = await _authContext();
      if (auth == null) return;
      _backupInProgress = true;
      final ok = await _backupData(auth.userId);
      if (ok) await prefs.remove(_kPendingBackupUserId);
    } catch (e) {
      debugPrint('[Cloudflare] pending backup failed: $e');
    } finally {
      _backupInProgress = false;
    }
  }

  Future<bool> backupPlaylists(String userId) async {
    final auth = await _authContext();
    if (auth == null) return false;
    if (!await isOnline()) {
      await _queuePendingBackup(auth.userId);
      return false;
    }
    if (_backupInProgress) return false;
    await _flushPendingBackup();
    try {
      _backupInProgress = true;
      return await _backupPlaylistsOnly(auth.userId);
    } finally {
      _backupInProgress = false;
    }
  }

  Future<bool> _backupPlaylistsOnly(String userId) async {
    final auth = await _authContext();
    if (auth == null) return false;
    final resolvedUserId = auth.userId;
    final headers = _headers(auth.token, json: true);
    final playlists = OtyaDatabase.instance.getAllPlaylists();
    var synced = 0;
    const batchSize = 5;
    for (var i = 0; i < playlists.length; i += batchSize) {
      final batch = playlists.skip(i).take(batchSize);
      final results = await Future.wait(batch.map((pl) async {
        try {
          final res = await _client.post(
            Uri.parse(Environment.apiPlaylistsUrl),
            headers: headers,
            body: jsonEncode({
              'id': '${resolvedUserId}_${pl.id}',
              'user_id': resolvedUserId,
              'name': pl.name,
              'media_ids': jsonEncode(pl.mediaIds),
            }),
          ).timeout(_timeout);
          return res.statusCode >= 200 && res.statusCode < 300;
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
    final auth = await _authContext();
    if (auth == null) return -1;
    final resolvedUserId = auth.userId;
    try {
      final res = await _client.get(
        Uri.parse('${Environment.apiPlaylistsUrl}?user_id=${Uri.encodeQueryComponent(resolvedUserId)}'),
        headers: _headers(auth.token),
      ).timeout(_timeout);
      if (res.statusCode != 200) return -1;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['playlists'] as List<dynamic>?) ?? [];
      var restored = 0;
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
          id: id.replaceFirst('${resolvedUserId}_', ''),
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
    final auth = await _authContext();
    if (auth == null) return;
    if (!await isOnline()) {
      await _queuePendingBackup(auth.userId);
      return;
    }
    if (_backupInProgress) return;
    try {
      _backupInProgress = true;
      await _backupHistoryOnly(auth.userId);
    } finally {
      _backupInProgress = false;
    }
  }

  Future<bool> _backupHistoryOnly(String userId) async {
    final auth = await _authContext();
    if (auth == null) return false;
    final resolvedUserId = auth.userId;
    final headers = _headers(auth.token, json: true);
    final history = OtyaDatabase.instance.getRecentlyPlayed(limit: 200);
    var synced = 0;
    const batchSize = 10;
    for (var i = 0; i < history.length; i += batchSize) {
      final batch = history.skip(i).take(batchSize);
      final results = await Future.wait(batch.map((item) async {
        try {
          final res = await _client.post(
            Uri.parse(Environment.apiHistoryUrl),
            headers: headers,
            body: jsonEncode({
              'id': '${resolvedUserId}_${item.id}',
              'user_id': resolvedUserId,
              'title': item.title,
              'artist': item.artist ?? '',
              'file_path': item.filePath,
              'is_video': item.isVideo ? '1' : '0',
              'last_played_at': item.lastPlayedAt?.toIso8601String() ?? '',
            }),
          ).timeout(_timeout);
          return res.statusCode >= 200 && res.statusCode < 300;
        } catch (e) {
          debugPrint('[Cloudflare] history upload failed: $e');
          return false;
        }
      }));
      synced += results.where((ok) => ok).length;
    }
    return synced == history.length;
  }

  Future<void> saveProExpiry(String userId, int expiryMs) async {
    if (!await isOnline()) return;
    final auth = await _authContext();
    if (auth == null) return;
    try {
      await _client.post(
        Uri.parse(Environment.apiProUrl),
        headers: _headers(auth.token, json: true),
        body: jsonEncode({'user_id': auth.userId, 'expiry_ms': expiryMs}),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[Cloudflare] saveProExpiry failed: $e');
    }
  }

  Future<int> fetchProExpiry(String userId) async {
    if (!await isOnline()) return 0;
    final auth = await _authContext();
    if (auth == null) return 0;
    try {
      final res = await _client.get(
        Uri.parse('${Environment.apiProUrl}?user_id=${Uri.encodeQueryComponent(auth.userId)}'),
        headers: _headers(auth.token),
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
    final auth = await _authContext();
    if (auth == null) return false;
    final playlistsOk = await _backupPlaylistsOnly(auth.userId);
    final historyOk = await _backupHistoryOnly(auth.userId);
    if (playlistsOk && historyOk) {
      unawaited(AppSyncService.instance.syncOnlineIfNeeded(null));
      return true;
    }
    return false;
  }

  Future<bool> backupAll(String userId) async {
    final auth = await _authContext();
    if (auth == null) return false;
    if (!await isOnline() || _backupInProgress) {
      await _queuePendingBackup(auth.userId);
      return false;
    }
    _backupInProgress = true;
    try {
      return await _backupData(auth.userId);
    } catch (e) {
      debugPrint('[Cloudflare] backupAll failed: $e');
      await _queuePendingBackup(auth.userId);
      return false;
    } finally {
      _backupInProgress = false;
    }
  }
}
