// lib/core/services/backup_service.dart
//
// Handles Drive backup via Auth Worker endpoints.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'http_client.dart';

const _kAuthBase = 'https://petersmartlink.com/auth';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  // Delegate to the app-wide singleton HTTP client — avoids duplicate
  // persistent connections and lets AppHttpClient manage the lifecycle.
  http.Client get _client => AppHttpClient.instance.client;
  static const Duration _timeout = Duration(seconds: 30);

  Future<void> backup(Map<String, dynamic> data, String driveAccessToken) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) throw Exception('Not logged in');
    final res = await _client.post(
      Uri.parse('$_kAuthBase/backup'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'drive_token': driveAccessToken, 'data': data}),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Backup failed (${res.statusCode})');
    }
  }

  Future<Map<String, dynamic>?> restore(String driveAccessToken) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) throw Exception('Not logged in');
    final uri = Uri.parse('$_kAuthBase/backup')
        .replace(queryParameters: {'drive_token': driveAccessToken});
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(_timeout);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Restore failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>?;
  }

  Future<void> deleteBackup(String driveAccessToken) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) throw Exception('Not logged in');
    final res = await _client.delete(
      Uri.parse('$_kAuthBase/backup'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'drive_token': driveAccessToken}),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Delete failed (${res.statusCode})');
    }
  }

  Future<Map<String, dynamic>> buildBackupData() async {
    final playlists = PlayedDatabase.instance.getAllPlaylists()
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'mediaIds': p.mediaIds,
              'createdAt': p.createdAt.toIso8601String(),
              'updatedAt': p.updatedAt.toIso8601String(),
            })
        .toList();

    return {
      'version':    1,
      'created_at': DateTime.now().toIso8601String(),
      'playlists':  playlists,
      'eq_presets': <dynamic>[],
      'bookmarks':  <dynamic>[],
    };
  }

  Future<void> restoreFromData(Map<String, dynamic> data) async {
    // Restore playlists
    try {
      final playlists = data['playlists'] as List<dynamic>? ?? [];
      debugPrint('[BackupService] Restoring ${playlists.length} playlists');
      for (final raw in playlists) {
        final map = raw as Map<String, dynamic>;
        final now = DateTime.now();
        final playlist = Playlist(
          id:        map['id'] as String,
          name:      map['name'] as String,
          mediaIds:  List<String>.from(map['mediaIds'] as List? ?? []),
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? now,
          updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? now,
        );
        await PlayedDatabase.instance.savePlaylist(playlist);
      }
    } catch (e) { debugPrint('[BackupService] playlists restore failed: $e'); }

  }
}
