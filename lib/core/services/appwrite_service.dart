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
///
/// APPWRITE DASHBOARD SETUP (one-time):
///   1. Go to https://cloud.appwrite.io/console/project-6a3011f1003b1a6cc74d
///   2. Auth → Settings → enable Google OAuth provider
///   3. Platforms → Add Android platform: com.otyaplayer.app
///   4. Databases → Create database: ID = 'otya-db'
///   5. Inside otya-db create 5 collections:
///
///      'playlists'
///        name(string, required), media_ids(string, required),
///        created_at(string), updated_at(string), user_id(string, required)
///        Permissions: role:user (read, write)
///
///      'play_history'
///        title(string), artist(string), file_path(string, required),
///        is_video(boolean), last_played_at(string), user_id(string, required)
///        Permissions: role:user (read, write)
///
///      'pro_status'
///        expiry_ms(integer), updated_at(string)
///        Permissions: role:user (read, write)
///
///      'releases'  ← written by CI/CD server API key, read by anyone
///        version(string, required), versionCode(integer, required),
///        date(string), changelog(string), arm64Url(string), arm32Url(string),
///        downloadUrl(string), minSdk(integer), targetSdk(integer)
///        Permissions: role:any (read), role:users (write)
///
///      'devices'  ← written by app on first launch (no auth required)
///        deviceId(string, required), userId(string), appVersion(string),
///        versionCode(integer), abi(string), platform(string),
///        registeredAt(string), lastSeenAt(string)
///        Permissions: role:any (create, read), role:users (update)
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
    debugPrint('[Appwrite] Initialized — project: ${Environment.appwriteProjectId}');
  }

  void _ensureInit() {
    if (!_initialized) init();
  }

  // -- Auth -------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    _ensureInit();
    try {
      await _account.createOAuth2Session(
        provider: OAuthProvider.google,
        success: 'appwrite-callback-${Environment.appwriteProjectId}:///',
        failure: 'appwrite-callback-${Environment.appwriteProjectId}:///failure',
        scopes: ['profile', 'email'],
      );
      // Store sign-in metadata in user prefs so providers can read it
      try {
        final user = await _account.get();
        await _account.updatePrefs(prefs: {
          ...user.prefs.data,
          'signedInWith': 'google',
          'email': user.email,
        });
      } catch (e) {
        debugPrint('[Appwrite] Could not update prefs after sign-in: $e');
      }
      _notifyAuthChange();
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
      _notifyAuthChange();
      debugPrint('[Appwrite] Signed out.');
    } catch (e) {
      debugPrint('[Appwrite] Sign out failed: $e');
    }
  }

  // -- Releases (read-only from app) -----------------------------------------

  /// Fetches the latest release document from Appwrite.
  /// Returns null if unavailable — app falls back to Worker /version endpoint.
  Future<Map<String, dynamic>?> fetchLatestRelease() async {
    _ensureInit();
    try {
      final result = await _databases.listDocuments(
        databaseId:   Environment.databaseId,
        collectionId: Environment.releasesCollection,
        queries:      [
          Query.orderDesc('versionCode'),
          Query.limit(1),
        ],
      );
      if (result.documents.isEmpty) return null;
      return result.documents.first.data;
    } catch (e) {
      debugPrint('[Appwrite] fetchLatestRelease failed: $e');
      return null;
    }
  }

  /// Helper: list all documents in a collection with automatic pagination
  /// so callers never silently miss items beyond the default 25-doc page.
  Future<List<models.Document>> _listAll({
    required String collectionId,
    List<String> queries = const [],
  }) async {
    final all      = <models.Document>[];
    int   offset   = 0;
    int   page     = 0;
    const pageSize = 100;
    const maxPages = 50;
    while (page < maxPages) {
      final result = await _databases.listDocuments(
        databaseId:   Environment.databaseId,
        collectionId: collectionId,
        queries:      [...queries, Query.limit(pageSize), Query.offset(offset)],
      );
      all.addAll(result.documents);
      page++;
      if (result.documents.length < pageSize) break;
      offset += pageSize;
    }
    if (page >= maxPages) {
      debugPrint('[Appwrite] _listAll: hit max page limit ($maxPages pages) for $collectionId');
    }
    return all;
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

  Future<int> restorePlaylists() async {
    _ensureInit();
    final user = await getCurrentUser();
    if (user == null) return -1;
    try {
      final userId = user.$id;
      final docs = await _listAll(
        collectionId: Environment.playlistsCollection,
        queries:      [Query.equal('user_id', userId)],
      );
      int restored = 0;
      for (final doc in docs) {
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
      debugPrint('[Appwrite] restorePlaylists failed: $e');
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

    // Fix #4: batch requests in groups of 10 with Future.wait instead of
    // sequential await — reduces wall-clock time from O(n) serial round-trips
    // to O(n/10) parallel batches without overwhelming the Appwrite API.
    int synced = 0;
    const batchSize = 10;
    for (var i = 0; i < history.length; i += batchSize) {
      final batch = history.skip(i).take(batchSize);
      final results = await Future.wait(
        batch.map((item) async {
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
            return true;
          } catch (e) {
            debugPrint('[Appwrite] Failed to sync history item: $e');
            return false;
          }
        }),
      );
      synced += results.where((ok) => ok).length;
    }
    debugPrint('[Appwrite] Synced $synced/${history.length} history items.');
  }

  // -- Full Backup ------------------------------------------------------------

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
