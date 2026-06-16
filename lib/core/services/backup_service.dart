import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/played_database.dart';
import '../models/playlist.dart';

/// Google Drive backup service — STUB.
///
/// Google Drive backup requires the following packages which are not yet
/// added to pubspec.yaml:
///   googleapis: ^12.0.0
///   googleapis_auth: ^1.6.0
///   google_sign_in: ^6.0.0
///
/// Until those are added, all methods are no-ops that return safe defaults.
/// The Appwrite backup (AppwriteService) is the active backup solution.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _backupFileName = 'played_backup.json';

  /// Backs up playlists and play history.
  /// Returns true on success, false if Drive is unavailable.
  Future<bool> backup() async {
    debugPrint('[Backup] Google Drive backup not yet configured — skipping.');
    return false;
  }

  /// Restores playlists from Google Drive backup.
  /// Returns the number of playlists restored, or -1 on failure.
  Future<int> restore() async {
    debugPrint('[Backup] Google Drive restore not yet configured — skipping.');
    return -1;
  }

  // ── Helpers (kept for future use) ────────────────────────────────────

  String _buildPayload() {
    final playlists = PlayedDatabase.instance.getAllPlaylists();
    final history   = PlayedDatabase.instance.getRecentlyPlayed(limit: 500);
    return jsonEncode({
      'version': 1,
      'backed_up_at': DateTime.now().toIso8601String(),
      'playlists': playlists.map((p) => {
        'id':        p.id,
        'name':      p.name,
        'media_ids': p.mediaIds,
        'created_at': p.createdAt.toIso8601String(),
      }).toList(),
      'history': history.map((m) => {
        'id':       m.id,
        'title':    m.title,
        'artist':   m.artist,
        'file_path': m.filePath,
        'is_video': m.isVideo,
        'last_played_at': m.lastPlayedAt?.toIso8601String(),
      }).toList(),
    });
  }

  List<Playlist> _parsePlaylists(String json) {
    final data  = jsonDecode(json) as Map<String, dynamic>;
    final lists = (data['playlists'] as List<dynamic>? ?? []);
    return lists.map((raw) {
      final map = raw as Map<String, dynamic>;
      return Playlist(
        id:        map['id'] as String,
        name:      map['name'] as String,
        mediaIds:  List<String>.from(map['media_ids'] as List),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }
}
