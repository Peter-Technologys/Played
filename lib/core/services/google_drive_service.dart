import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Google Drive REST API v3 client — pure Dart, no native plugin.
/// The caller provides a valid OAuth 2.0 Bearer token.
class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService instance = GoogleDriveService._();

  static const _files   = 'https://www.googleapis.com/drive/v3/files';
  static const _upload  = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _name    = 'my_media_player_backup.json';
  static const _mime    = 'application/json';

  Future<void> backup({
    required String accessToken,
    required Map<String, dynamic> data,
  }) async {
    final body    = jsonEncode(data);
    final headers = {'Authorization': 'Bearer $accessToken'};
    final id      = await findExistingBackupId(accessToken: accessToken);
    if (id != null) {
      await _patch(id, body, headers);
    } else {
      await _create(body, headers);
    }
  }

  Future<Map<String, dynamic>?> restore({required String accessToken}) async {
    final id = await findExistingBackupId(accessToken: accessToken);
    if (id == null) return null;
    final res = await http.get(
      Uri.parse('$_files/$id?alt=media'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String?> findExistingBackupId({required String accessToken}) async {
    final q   = Uri.encodeQueryComponent("name='$_name' and trashed=false");
    final res = await http.get(
      Uri.parse('$_files?q=$q&fields=files(id,name)&spaces=drive'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final files = ((jsonDecode(res.body) as Map)['files'] as List?) ?? [];
    if (files.isEmpty) return null;
    return (files.first as Map)['id'] as String?;
  }

  Future<void> _create(String body, Map<String, String> auth) async {
    const boundary = 'otya_boundary';
    final meta = jsonEncode({'name': _name, 'mimeType': _mime});
    final mp   = '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'
                 '$meta\r\n--$boundary\r\nContent-Type: $_mime\r\n\r\n'
                 '$body\r\n--$boundary--';
    final res = await http.post(
      Uri.parse('$_upload?uploadType=multipart'),
      headers: {...auth, 'Content-Type': 'multipart/related; boundary=$boundary'},
      body: mp,
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) throw Exception('Drive token expired: re-authenticate required');
    if (res.statusCode != 200 && res.statusCode != 201)
      throw Exception('Drive create failed: ${res.statusCode}');
    debugPrint('[DriveService] Backup created.');
  }

  Future<void> _patch(String id, String body, Map<String, String> auth) async {
    final res = await http.patch(
      Uri.parse('$_upload/$id?uploadType=media'),
      headers: {...auth, 'Content-Type': _mime},
      body: body,
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) throw Exception('Drive token expired: re-authenticate required');
    if (res.statusCode != 200)
      throw Exception('Drive patch failed: ${res.statusCode}');
    debugPrint('[DriveService] Backup updated.');
  }
}
