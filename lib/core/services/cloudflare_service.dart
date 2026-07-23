import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../database/played_database.dart';
import '../models/playlist.dart';

/// CloudflareService — replaces Appwrite DB calls for playlists, history,
/// and pro status. Auth (Google OAuth) still goes through AppwriteService.
///
/// All endpoints live at petersmartlink.com (Cloudflare Worker + D1).
/// Every method is fire-and-forget safe: errors are logged, never thrown.
class CloudflareService {
  CloudflareService._();
  static final CloudflareService instance = CloudflareService._();

  static const Duration _timeout = Duration(seconds: 12);

  // ── Playlists ─────────────────────────────────────────────────────────────

  Future<void> backupPlaylists(String userId) async {
    final playlists = PlayedDatabase.instance.getAllPlaylists();
    int synced = 0;
    for (final pl in playlists) {
      try {
        final res = await http.post(
          Uri.parse(Environment.apiPlaylistsUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id':        '${userId}_${pl.id}',
            'user_id':   userId,
            'name':      pl.name,
            'media_ids': jsonEncode(pl.mediaIds),
          }),
        ).timeout(_timeout);
        if (res.statusCode == 200) synced++;
      } catch (e) {
        debugPrint('[Cloudflare] backupPlaylists item failed: $e');
      }
    }
    debugPrint('[Cloudflare] Synced $synced/${playlists.length} playlists.');
  }

  Future<int> restorePlaylists(String userId) async {
    try {
      final res = await http
          .get(Uri.parse('${Environment.apiPlaylistsUrl}?user_id=$userId'))
          .timeout(_timeout);
      if (res.statusCode != 200) return -1;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['playlists'] as List<dynamic>?) ?? [];
      int restored = 0;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
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
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 200);
    int synced = 0;
    const batchSize = 10;
    for (var i = 0; i < history.length; i += batchSize) {
      final batch = history.skip(i).take(batchSize);
      final results = await Future.wait(batch.map((item) async {
        try {
          final res = await http.post(
            Uri.parse(Environment.apiHistoryUrl),
            headers: {'Content-Type': 'application/json'},
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
    try {
      await http.post(
        Uri.parse(Environment.apiProUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'expiry_ms': expiryMs}),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[Cloudflare] saveProExpiry failed: $e');
    }
  }

  Future<int> fetchProExpiry(String userId) async {
    try {
      final res = await http
          .get(Uri.parse('${Environment.apiProUrl}?user_id=$userId'))
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
