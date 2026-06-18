import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import '../config/environment.dart';
import '../database/played_database.dart';
import '../models/playlist.dart';

/// Appwrite service for OTYA Player.
///
/// Auth: Google OAuth only (no email/password).
/// On sign-in, all local data (playlists + history) is automatically
/// backed up to the user's Appwrite account.
/// On sign-out, local data is kept on device.
///
/// APPWRITE DASHBOARD SETUP (one-time):
///   1. Go to https://cloud.appwrite.io/console/project-6a3011f1003b1a6cc74d
///   2. Auth -> Settings -> enable Google OAuth provider
///      (add your Google OAuth client ID + secret from Google Cloud Console)
///   3. Platforms -> Add Android platform:
///        Package name: com.petersmartlink.otya
///   4. Databases -> Create database: ID = 'otya-db'
///   5. Inside otya-db create 3 collections:
///        - 'playlists'    attributes: name(string), media_ids(string), created_at(string)
///        - 'play_history' attributes: title(string), artist(string), file_path(string),
///                                     is_video(boolean), last_played_at(string)
///        - 'pro_status'   attributes: expiry_ms(integer), updated_at(string)
///   6. Each collection permissions: role:user (read, write)
class AppwriteService {
  AppwriteService._();
  static final AppwriteService instance = AppwriteService._();

  late final Client    _client;
  late final Account   _account;
  late final Databases _databases;
  bool _initialized = false;

  // Notifies listeners (auth_provider) when sign-in state changes.
  final _authChangeCallbacks = <void Function()>[];
  void addAuthListener(void Function() cb) => _authChangeCallbacks.add(cb);
  void _notifyAuthChange() {
    for (final cb in _authChangeCallbacks) {
      cb();
    }
  }

  // -- Init -------------------------------------------------------------------

  void init() {
    if (_initialized) return;
    _client = Client()
      ..setEndpoint(Environment.appwriteEndpoint)
      ..setProject(Environment.appwriteProjectId)
      ..setSelfSigned(status: false);
    _account   = Account(_client);
    _databases = Databases(_client);
    _initialized = true;
    debugPrint('[Appwrite] Initialized -- project: ${Environment.appwriteProjectId}');
  }

  void _ensureInit() {
    if (!_initialized) init();
  }

  // -- Auth -------------------------------------------------------------------

  /// Signs in with Google via Appwrite OAuth.
  /// After successful sign-in, automatically backs up all local data.
  Future<void> signInWithGoogle() async {
    _ensureInit();
    try {
      await _account.createOAuth2Session(
        provider: OAuthProvider.google,
        success: 'appwrite-callback-${Environment.appwriteProjectId}:///',
        failure: 'appwrite-callback-${Environment.appwriteProjectId}:///failure',
      );
      _notifyAuthChange();
      // Auto-backup after sign-in so user's data is immediately safe
      unawaited(_backupAfterSignIn());
    } catch (e) {
      debugPrint('[Appwrite] Google sign-in failed: $e');
      rethrow;
    }
  }

  Future<void> _backupAfterSignIn() async {
    try {
      await backupAll();
      debugPrint('[Appwrite] Auto-backup after sign-in complete.');
    } catch (e) {
      debugPrint('[Appwrite] Auto-backup after sign-in failed: $e');
    }
  }

  /// Returns the current signed-in user, or null if not signed in.
  Future<models.User?> getCurrentUser() async {
    _ensureInit();
    try {
      return await _account.get();
    } catch (_) {
      return null;
    }
  }

  /// Signs out and notifies listeners.
  Future<void> signOut() async {
    _ensureInit();
    try {
      await _account.deleteSession(sessionId: 'current');
      _notifyAuthChange();
      debugPrint('[Appwrite] Signed out.');
    } catch (e) {
      debugPrint('[Appwrite] Sign out failed: $e');
    }
  }

  // -- Playlist Backup --------------------------------------------------------

  Future<void> backupPlaylists() async {
    _ensureInit();
    final user = await getCurrentUser();
    if (user == null) {
      debugPrint('[Appwrite] backupPlaylists: not signed in, skipping.');
      return;
    }
    final userId = user.$id;
    final playlists = PlayedDatabase.instance.getAllPlaylists();
    int synced = 0;
    for (final pl in playlists) {
      try {
        final data = {
          'name':       pl.name,
          'media_ids':  jsonEncode(pl.mediaIds),
          'created_at': pl.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'user_id':    userId,
        };
        try {
          await _databases.updateDocument(
            databaseId:   Environment.databaseId,
            collectionId: Environment.playlistsCollection,
            documentId:   '${userId}_${pl.id}',
            data:         data,
          );
        } on AppwriteException catch (ae) {
          if (ae.code == 404) {
            await _databases.createDocument(
              databaseId:   Environment.databaseId,
              collectionId: Environment.playlistsCollection,
              documentId:   '${userId}_${pl.id}',
              data:         data,
            );
          } else {
            rethrow;
          }
        }
        synced++;
      } catch (e) {
        debugPrint('[Appwrite] Failed to sync playlist "${pl.name}": $e');
      }
    }
    debugPrint('[Appwrite] Synced $synced/${playlists.length} playlists.');
  }

  /// Downloads this user's playlists from Appwrite and merges into local DB.
  /// Returns number of playlists restored, or -1 on failure.
  Future<int> restorePlaylists() async {
    _ensureInit();
    final user = await getCurrentUser();
    if (user == null) return -1;
    try {
      final userId = user.$id;
      final result = await _databases.listDocuments(
        databaseId:   Environment.databaseId,
        collectionId: Environment.playlistsCollection,
        queries:      [Query.equal('user_id', userId)],
      );
      int restored = 0;
      for (final doc in result.documents) {
        final data = doc.data;
        final playlist = Playlist(
          id:        doc.$id.replaceFirst('${userId}_', ''),
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

  // -- History Backup ---------------------------------------------------------

  Future<void> backupHistory() async {
    _ensureInit();
    final user = await getCurrentUser();
    if (user == null) return;
    final userId = user.$id;
    final history = PlayedDatabase.instance.getRecentlyPlayed(limit: 200);
    int synced = 0;
    for (final item in history) {
      try {
        final data = {
          'title':          item.title,
          'artist':         item.artist ?? '',
          'file_path':      item.filePath,
          'is_video':       item.isVideo,
          'last_played_at': item.lastPlayedAt?.toIso8601String() ?? '',
          'user_id':        userId,
        };
        try {
          await _databases.updateDocument(
            databaseId:   Environment.databaseId,
            collectionId: Environment.historyCollection,
            documentId:   '${userId}_${item.id}',
            data:         data,
          );
        } on AppwriteException catch (ae) {
          if (ae.code == 404) {
            await _databases.createDocument(
              databaseId:   Environment.databaseId,
              collectionId: Environment.historyCollection,
              documentId:   '${userId}_${item.id}',
              data:         data,
            );
          } else {
            rethrow;
          }
        }
        synced++;
      } catch (e) {
        debugPrint('[Appwrite] Failed to sync history item: $e');
      }
    }
    debugPrint('[Appwrite] Synced $synced history items.');
  }

  // -- Full Backup ------------------------------------------------------------

  /// Backs up playlists + history. Returns true on success.
  Future<bool> backupAll() async {
    try {
      await Future.wait([backupPlaylists(), backupHistory()]);
      return true;
    } catch (e) {
      debugPrint('[Appwrite] Full backup failed: $e');
      return false;
    }
  }

  // -- Pro Status -------------------------------------------------------------

  Future<void> saveProExpiry(int expiryMs) async {
    _ensureInit();
    final user = await getCurrentUser();
    if (user == null) return;
    final userId = user.$id;
    final data = {
      'expiry_ms':  expiryMs,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      try {
        await _databases.updateDocument(
          databaseId:   Environment.databaseId,
          collectionId: Environment.proStatusCollection,
          documentId:   userId,
          data:         data,
        );
      } on AppwriteException catch (ae) {
        if (ae.code == 404) {
          await _databases.createDocument(
            databaseId:   Environment.databaseId,
            collectionId: Environment.proStatusCollection,
            documentId:   userId,
            data:         data,
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('[Appwrite] saveProExpiry failed: $e');
    }
  }

  Future<int> fetchProExpiry() async {
    _ensureInit();
    final user = await getCurrentUser();
    if (user == null) return 0;
    try {
      final userId = user.$id;
      final doc = await _databases.getDocument(
        databaseId:   Environment.databaseId,
        collectionId: Environment.proStatusCollection,
        documentId:   userId,
      );
      return (doc.data['expiry_ms'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearProExpiry() async => saveProExpiry(0);
}
