// lib/core/services/backup_service.dart
//
// Handles Drive backup via Auth Worker endpoints.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const _kAuthBase = 'https://petersmartlink.com/auth';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static final http.Client _client = http.Client();
  static const Duration _timeout   = Duration(seconds: 30);

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
    final data = <String, dynamic>{
      'version':    1,
      'created_at': DateTime.now().toIso8601String(),
      'playlists':  <dynamic>[],
      'history':    <dynamic>[],
      'eq_presets': <dynamic>[],
      'bookmarks':  <dynamic>[],
    };
    return data;
  }

  Future<void> restoreFromData(Map<String, dynamic> data) async {
    try {
      final playlists = data['playlists'] as List<dynamic>? ?? [];
      debugPrint('[BackupService] Restoring ${playlists.length} playlists');
    } catch (e) { debugPrint('[BackupService] playlists restore failed: $e'); }
    try {
      final history = data['history'] as List<dynamic>? ?? [];
      debugPrint('[BackupService] Restoring ${history.length} history entries');
    } catch (e) { debugPrint('[BackupService] history restore failed: $e'); }
    try {
      final eq = data['eq_presets'] as List<dynamic>? ?? [];
      debugPrint('[BackupService] Restoring ${eq.length} EQ presets');
    } catch (e) { debugPrint('[BackupService] eq_presets restore failed: $e'); }
    try {
      final bm = data['bookmarks'] as List<dynamic>? ?? [];
      debugPrint('[BackupService] Restoring ${bm.length} bookmarks');
    } catch (e) { debugPrint('[BackupService] bookmarks restore failed: $e'); }
  }
}
