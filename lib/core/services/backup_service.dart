import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../database/played_database.dart';
import '../models/playlist.dart';

/// Google Drive backup service for PLAYED.
///
/// Backs up:
///   - All playlists (names + track IDs)
///   - Play history (recently played track metadata)
///
/// Files are stored in a hidden app folder in the user's Google Drive
/// (appDataFolder scope) — invisible to the user in Drive UI.
///
/// SETUP:
///   1. Enable Google Drive API in Google Cloud Console.
///   2. Add the googleapis and googleapis_auth packages to pubspec.yaml:
///        googleapis: ^12.0.0
///        googleapis_auth: ^1.6.0
///   3. The user must be signed in with Google (AuthService.signInWithGoogle).
///   4. Call BackupService.instance.backup() from Settings screen.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _backupFileName = 'played_backup.json';
  static const _scopes = [drive.DriveApi.driveAppdataScope];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  // ── Auth ────────────────────────────────────────────────────────────

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final account = await _googleSignIn.signInSilently() ??
          await _googleSignIn.signIn();
      if (account == null) return null;

      final authHeaders = await account.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('[Backup] Drive auth failed: $e');
      return null;
    }
  }

  // ── Backup ──────────────────────────────────────────────────────────

  /// Backs up playlists and play history to Google Drive appDataFolder.
  /// Returns true on success.
  Future<bool> backup() async {
    final api = await _getDriveApi();
    if (api == null) return false;

    try {
      final playlists = PlayedDatabase.instance.getAllPlaylists();
      final history   = PlayedDatabase.instance.getRecentlyPlayed(limit: 500);

      final payload = jsonEncode({
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

      final bytes  = utf8.encode(payload);
      final stream = Stream.fromIterable([bytes]);

      // Check if backup file already exists
      final existing = await _findBackupFile(api);

      if (existing != null) {
        // Update existing file
        await api.files.update(
          drive.File(),
          existing,
          uploadMedia: drive.Media(stream, bytes.length),
        );
      } else {
        // Create new file in appDataFolder
        final file = drive.File()
          ..name    = _backupFileName
          ..parents = ['appDataFolder'];
        await api.files.create(
          file,
          uploadMedia: drive.Media(stream, bytes.length),
        );
      }

      debugPrint('[Backup] Backed up ${playlists.length} playlists, '
          '${history.length} history items.');
      return true;
    } catch (e) {
      debugPrint('[Backup] Backup failed: $e');
      return false;
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────

  /// Restores playlists from Google Drive backup.
  /// Returns the number of playlists restored, or -1 on failure.
  Future<int> restore() async {
    final api = await _getDriveApi();
    if (api == null) return -1;

    try {
      final fileId = await _findBackupFile(api);
      if (fileId == null) {
        debugPrint('[Backup] No backup file found in Drive.');
        return 0;
      }

      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes  = await media.stream.expand((b) => b).toList();
      final json   = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final lists  = (json['playlists'] as List<dynamic>? ?? []);

      int restored = 0;
      for (final raw in lists) {
        final map = raw as Map<String, dynamic>;
        final playlist = Playlist(
          id:        map['id'] as String,
          name:      map['name'] as String,
          mediaIds:  List<String>.from(map['media_ids'] as List),
          createdAt: DateTime.parse(map['created_at'] as String),
          updatedAt: DateTime.now(),
        );
        await PlayedDatabase.instance.savePlaylist(playlist);
        restored++;
      }

      debugPrint('[Backup] Restored $restored playlists.');
      return restored;
    } catch (e) {
      debugPrint('[Backup] Restore failed: $e');
      return -1;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Future<String?> _findBackupFile(drive.DriveApi api) async {
    try {
      final list = await api.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id)',
      );
      return list.files?.firstOrNull?.id;
    } catch (_) {
      return null;
    }
  }
}

/// Minimal HTTP client that injects Google auth headers.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
