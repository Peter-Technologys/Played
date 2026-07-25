import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../database/played_database.dart';
import '../models/playlist.dart';
import '../utils/connectivity_utils.dart';
import 'api_signer.dart';

/// CloudflareService — handles playlists, history, and pro status via
/// the Cloudflare Worker + D1 backend at petersmartlink.com.
/// Every request is HMAC-signed via ApiSigner.
/// Every method is fire-and-forget safe: errors are logged, never thrown.
class CloudflareService {
  CloudflareService._();
  static final CloudflareService instance = CloudflareService._();

  static const Duration _timeout = Duration(seconds: 12);

  // Single reusable HTTP client — avoids TCP setup overhead on every call.
  static final http.Client _client = http.Client();

  // SharedPreferences key: stores the userId of a backup that was skipped
  // because the device was offline. Flushed on the next successful online sync.
  static const String _kPendingBackupUserId = 'otya_pending_backup_user_id';

  /// Stores userId so the next online sync picks up what was missed offline.
  Future<void> _queuePendingBackup(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingBackupUserId, userId);
      debugPrint('[Cloudflare] Queued pending backup for $userId.');
    } catch (e) {
      debugPrint('[Cloudflare] _queuePendingBackup failed: $e');
    }
  }

  /// If a backup was queued while offline, run it now (device is online).
  Future<void> _flushPendingBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_kPendingBackupUserId);
      if (userId == null) return;
      await prefs.remove(_kPendingBackupUserId);
      debugPrint('[Cloudflare] Flushing pending backup for $userId.');
      // Key already removed above, so recursive calls to _flushPendingBackup
      // from backupAll → backupPlaylists/backupHistory will be no-ops.
      await backupAll(userId);
    } catch (e) {
      debugPrint('[Cloudflare] _flushPendingBackup failed: $e');
    }
  }

  /// Disposes the shared HTTP client. Call only on app shutdown.
  static void dispose() => _client.close();

  // ── Signed header helpers ─────────────────────────────────────────────────

  Map<String, String> _getHeaders(String path) =>
      ApiSigner.signedHeaders(method: 'GET', path: path);

  Map<String, String> _postHeaders(String path) => {
    ...ApiSigner.signedHeaders(method: 'POST', path: path),
    'Content-Type': 'application/json',
  };

  // ── Playlists ─────────────────────────────────────────────────────────────

  Future<void> backupPlaylists(String userId) async {
    if (!await isOnline()) {
      debugPrint('[Cloudflare] backupPlaylists: offline — queuing for later.');
      await _queuePendingBackup(userId);
      return;
    }
    // Flush any backup that was missed while the device was last offline.
    unawaited(_flushPendingBackup());
    final playlists = PlayedDatabase.instance.getAllPlaylists();
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
              'id':        '${userId}_${pl.id}',
              'user_id':   userId,
              'name':      pl.name,
              'media_ids': jsonEncode(pl.mediaIds),
            }),
          ).timeout(_timeout);
          return res.statusCode == 200;
        } catch (e) {
          debugPrint('[Cloudflare] backupPlaylists item failed: $e');
          return false;
        }
      }));
      synced += results.where((ok) => ok).length;
    }
    debugPrint('[Cloudflare] Synced $synced/${playlists.length} playlists.');
  }

  Future<int> restorePlaylists(String userId) async {
    try {
      const path = '/api/playlists';
      final res = await _client
          .get(
            Uri.parse('${Environment.apiPlaylistsUrl}?user_id=$userId'),
            headers: _getHeaders(path),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return -1;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['playlists'] as List<dynamic>?) ?? [];
      int restored = 0;
      for (final item in list) {
        final map   = item as Map<String, dynamic>;
        final rawId = (map['id'] as String).replaceFirst('${userId}_', '');
        final playlist = Playlist(
          id:        rawId,
          name:      map['name'] as String,
          mediaIds:  List<String>.from(
              jsonDecode(map['media_ids'] as String) as List),
          createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
              DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await PlayedDatabase.instance.savePlaylist(playlist);
        restored++;
      }
      debugPrint('[Cloudflare] Restored $restored playlists.');
      return restored;
    } catch (e) {
      debugPrint('[Cloudflare] restorePlaylists failed: $e');
      return -1;
    }
  }

  // ── Play history ──────────────────────────────────────────────────────────

  Future<void> backupHistory(String userId) async {
    if (!await isOnline()) {
      debugPrint('[Cloudflare] backupHistory: offline — queuing for later.');
      await _queuePendingBackup(userId);
      return;
    }
    unawaited(_flushPendingBackup());
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 200);
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
              'id':             '${userId}_${item.id}',
              'user_id':        userId,
              'title':          item.title,
              'artist':         item.artist ?? '',
              'file_path':      item.filePath,
              'is_video':       item.isVideo ? '1' : '0',
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
    debugPrint('[Cloudflare] Synced $synced/${history.length} history items.');
  }

  // ── Pro status ────────────────────────────────────────────────────────────

  Future<void> saveProExpiry(String userId, int expiryMs) async {
    if (!await isOnline()) {
      debugPrint('[Cloudflare] saveProExpiry: offline, skipping.');
      return;
    }
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
    if (!await isOnline()) {
      debugPrint('[Cloudflare] fetchProExpiry: offline, skipping.');
      return 0;
    }
    try {
      const path = '/api/pro';
      final res = await _client
          .get(
            Uri.parse('${Environment.apiProUrl}?user_id=$userId'),
            headers: _getHeaders(path),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return 0;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['expiry_ms'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[Cloudflare] fetchProExpiry failed: $e');
      return 0;
    }
  }

  // ── Full backup ───────────────────────────────────────────────────────────

  Future<bool> backupAll(String userId) async {
    try {
      await Future.wait([
        backupPlaylists(userId),
        backupHistory(userId),
      ]);
      return true;
    } catch (e) {
      debugPrint('[Cloudflare] backupAll failed: $e');
      return false;
    }
  }
}
