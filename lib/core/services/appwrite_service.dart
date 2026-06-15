import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import '../config/environment.dart';
import '../database/played_database.dart';
import '../models/playlist.dart';

/// Appwrite cloud sync service for PLAYED.
///
/// Uses the dedicated PLAYED Appwrite project (ID: 6a3011f1003b1a6cc74d).
/// This project is 100% isolated from all other PeterSmart apps —
/// no other app can read or write to this project's data.
///
/// SETUP (one-time in Appwrite Dashboard):
///   1. Go to https://cloud.appwrite.io/console/project-6a3011f1003b1a6cc74d
///   2. Create Database: ID = 'played-db'
///   3. Create Collections inside played-db:
///        - 'playlists'    (attributes: name string, media_ids string, created_at string)
///        - 'play_history' (attributes: title string, artist string, file_path string,
///                          is_video boolean, last_played_at string)
///        - 'pro_status'   (attributes: expiry_ms integer, updated_at string)
///   4. Set Collection permissions: role:user (read, write) on all collections
///   5. Add Android platform in Appwrite → Settings → Platforms:
///        Package name: com.petersmart.played
///
/// PUBSPEC: Add to pubspec.yaml:
///   appwrite: ^13.0.0
class AppwriteService {
  AppwriteService._();
  static final AppwriteService instance = AppwriteService._();

  late final Client _client;
  late final Account _account;
  late final Databases _databases;
  bool _initialized = false;

  // ── Init ────────────────────────────────────────────────────────────────

  void init() {
    if (_initialized) return;
    _client = Client()
      ..setEndpoint(Environment.appwriteEndpoint)
      ..setProject(Environment.appwriteProjectId)
      ..setSelfSigned(status: false);
    _account   = Account(_client);
    _databases = Databases(_client);
    _initialized = true;
    debugPrint('[Appwrite] Initialized — project: ${Environment.appwriteProjectId}');
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Creates an anonymous Appwrite session if none exists.
  /// Called once at startup — user never sees a prompt.
  Future<void> signInAnonymouslyIfNeeded() async {
    _ensureInit();
    try {
      await _account.get(); // already signed in
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        try {
          await _account.createAnonymousSession();
          debugPrint('[Appwrite] Anonymous session created.');
        } catch (err) {
          debugPrint('[Appwrite] Anonymous sign-in failed (offline?): $err');
        }
      }
    }
  }

  /// Signs in with Google OAuth via Appwrite.
  Future<void> signInWithGoogle() async {
    _ensureInit();
    try {
      await _account.createOAuth2Session(
        provider: OAuthProvider.google,
        success: 'appwrite-callback-${Environment.appwriteProjectId}:///',
        failure: 'appwrite-callback-${Environment.appwriteProjectId}:///failure',
      );
    } catch (e) {
      debugPrint('[Appwrite] Google sign-in failed: $e');
      rethrow;
    }
  }

  Future<models.User?> getCurrentUser() async {
    _ensureInit();
    try {
      return await _account.get();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    _ensureInit();
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (e) {
      debugPrint('[Appwrite] Sign out failed: $e');
    }
  }

  // ── Playlist Sync ────────────────────────────────────────────────────────

  /// Uploads all local playlists to Appwrite (upsert — safe to call anytime).
  Future<void> backupPlaylists() async {
    _ensureInit();
    final playlists = PlayedDatabase.instance.getAllPlaylists();
    int synced = 0;
    for (final pl in playlists) {
      try {
        await _databases.upsertDocument(
          databaseId:   Environment.databaseId,
          collectionId: Environment.playlistsCollection,
          documentId:   pl.id,
          data: {
            'name':       pl.name,
            'media_ids':  jsonEncode(pl.mediaIds),
            'created_at': pl.createdAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
        synced++;
      } catch (e) {
        debugPrint('[Appwrite] Failed to sync playlist "${pl.name}": $e');
      }
    }
    debugPrint('[Appwrite] Synced $synced/${playlists.length} playlists.');
  }

  /// Downloads playlists from Appwrite and merges into local Hive DB.
  /// Returns the number of playlists restored, or -1 on failure.
  Future<int> restorePlaylists() async {
    _ensureInit();
    try {
      final result = await _databases.listDocuments(
        databaseId:   Environment.databaseId,
        collectionId: Environment.playlistsCollection,
      );
      int restored = 0;
      for (final doc in result.documents) {
        final data = doc.data;
        final playlist = Playlist(
          id:        doc.$id,
          name:      data['name'] as String,
          mediaIds:  List<String>.from(
              jsonDecode(data['media_ids'] as String) as List),
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.now(),
        );
        await PlayedDatabase.instance.savePlaylist(playlist);
        restored++;
      }
      debugPrint('[Appwrite] Restored $restored playlists.');
      return restored;
    } catch (e) {
      debugPrint('[Appwrite] Restore failed: $e');
      return -1;
    }
  }

  // ── Play History Sync ────────────────────────────────────────────────────

  /// Backs up the last 200 played tracks to Appwrite.
  Future<void> backupHistory() async {
    _ensureInit();
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 200);
    int synced = 0;
    for (final item in history) {
      try {
        await _databases.upsertDocument(
          databaseId:   Environment.databaseId,
          collectionId: Environment.historyCollection,
          documentId:   item.id,
          data: {
            'title':          item.title,
            'artist':         item.artist ?? '',
            'file_path':      item.filePath,
            'is_video':       item.isVideo,
            'last_played_at': item.lastPlayedAt?.toIso8601String() ?? '',
          },
        );
        synced++;
      } catch (e) {
        debugPrint('[Appwrite] Failed to sync history item: $e');
      }
    }
    debugPrint('[Appwrite] Synced $synced history items.');
  }

  // ── Full Backup ──────────────────────────────────────────────────────────

  /// Backs up everything: playlists + history. Returns true on success.
  Future<bool> backupAll() async {
    try {
      await Future.wait([backupPlaylists(), backupHistory()]);
      return true;
    } catch (e) {
      debugPrint('[Appwrite] Full backup failed: $e');
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _ensureInit() {
    if (!_initialized) init();
  }
}
