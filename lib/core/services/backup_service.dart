// lib/core/services/backup_service.dart
//
// Handles Drive backup via Auth Worker endpoints.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/otya_database.dart';
import '../models/playlist.dart';
import 'auth_service.dart';
import 'http_client.dart';

const _kAuthBase = 'https://petersmartlink.com/auth';
const _kBackupSchemaVersion = 1;

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  http.Client get _client => AppHttpClient.instance.client;
  static const Duration _timeout = Duration(seconds: 30);

  String _errorMessage(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) return error;
      }
    } catch (_) {}
    return '$fallback (${res.statusCode})';
  }

  Map<String, dynamic> _decodeObject(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    throw Exception(fallback);
  }

  Future<void> backup(Map<String, dynamic> data, String driveAccessToken) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) throw Exception('Please sign in to OTYA first.');
    final res = await _client.post(
      Uri.parse('$_kAuthBase/backup'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'drive_token': driveAccessToken, 'data': data}),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Backup failed'));
    }
  }

  Future<Map<String, dynamic>?> restore(String driveAccessToken) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) throw Exception('Please sign in to OTYA first.');
    final uri = Uri.parse('$_kAuthBase/backup')
        .replace(queryParameters: {'drive_token': driveAccessToken});
    final res = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Restore failed'));
    }
    final body = _decodeObject(res, 'The backup response was not valid.');
    final data = body['data'];
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw Exception('The Drive backup has an unsupported format.');
    }
    return data;
  }

  Future<void> deleteBackup(String driveAccessToken) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) throw Exception('Please sign in to OTYA first.');
    final res = await _client.delete(
      Uri.parse('$_kAuthBase/backup'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'drive_token': driveAccessToken}),
    ).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res, 'Delete failed'));
    }
  }

  Future<Map<String, dynamic>> buildBackupData() async {
    final playlists = OtyaDatabase.instance.getAllPlaylists()
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'mediaIds': p.mediaIds,
              'createdAt': p.createdAt.toIso8601String(),
              'updatedAt': p.updatedAt.toIso8601String(),
            })
        .toList();

    return {
      'schema_version': _kBackupSchemaVersion,
      'payload_type': 'otya_recovery_snapshot',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'playlists': playlists,
      'eq_presets': <dynamic>[],
      'bookmarks': <dynamic>[],
    };
  }

  Future<int> restoreFromData(Map<String, dynamic> data) async {
    final schemaVersion = data['schema_version'] ?? data['version'];
    if (schemaVersion is! int || schemaVersion != _kBackupSchemaVersion) {
      throw Exception('This backup version is not supported by this OTYA build.');
    }

    final rawPlaylists = data['playlists'];
    if (rawPlaylists != null && rawPlaylists is! List) {
      throw Exception('The Drive backup is damaged or incomplete.');
    }

    final playlists = rawPlaylists as List<dynamic>? ?? const [];
    debugPrint('[BackupService] Restoring ${playlists.length} playlists');
    var restored = 0;

    for (final raw in playlists) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id'];
      final name = raw['name'];
      if (id is! String || id.isEmpty || name is! String || name.isEmpty) continue;

      final now = DateTime.now();
      final playlist = Playlist(
        id: id,
        name: name,
        mediaIds: List<String>.from(raw['mediaIds'] as List? ?? const []),
        createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? now,
        updatedAt: DateTime.tryParse(raw['updatedAt'] as String? ?? '') ?? now,
      );
      await OtyaDatabase.instance.savePlaylist(playlist);
      restored++;
    }
    return restored;
  }
}
