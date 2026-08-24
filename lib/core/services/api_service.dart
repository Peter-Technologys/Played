// lib/core/services/api_service.dart
//
// Wraps all Otya-Store API calls.
// Automatically adds Authorization: Bearer {token} when user is logged in.
// Falls back to HMAC signing when not logged in (backward compat).

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'api_signer.dart';
import 'auth_service.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static final http.Client _client = http.Client();
  static const Duration _timeout   = Duration(seconds: 12);

  // ── Retry helper ──────────────────────────────────────────────────────────

  /// Executes [fn] with up to [maxRetries] retries on transient network
  /// errors (SocketException, TimeoutException). Uses exponential backoff
  /// starting at [initialDelay]. Non-retryable errors (4xx) are not retried.
  static Future<T?> _withRetry<T>(
    Future<T?> Function() fn, {
    int maxRetries = 2,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    Duration delay = initialDelay;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await fn();
      } on SocketException catch (e) {
        if (attempt == maxRetries) {
          debugPrint('[ApiService] SocketException after $maxRetries retries: $e');
          return null;
        }
      } on TimeoutException catch (e) {
        if (attempt == maxRetries) {
          debugPrint('[ApiService] TimeoutException after $maxRetries retries: $e');
          return null;
        }
      } catch (_) {
        // Non-retryable error (e.g. 4xx decoded as exception) — bail immediately.
        rethrow;
      }
      await Future<void>.delayed(delay);
      delay *= 2;
    }
    return null;
  }

  // ── Header helpers ────────────────────────────────────────────────────────

  Future<Map<String, String>> _getHeaders(String path) async {
    final token = await AuthService.instance.getValidToken();
    if (token != null) {
      return {
        'Authorization': 'Bearer $token',
        'Accept':        'application/json',
      };
    }
    return ApiSigner.signedHeaders(method: 'GET', path: path);
  }

  Future<Map<String, String>> _postHeaders(String path) async {
    final token = await AuthService.instance.getValidToken();
    if (token != null) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
        'Accept':        'application/json',
      };
    }
    return {
      ...ApiSigner.signedHeaders(method: 'POST', path: path),
      'Content-Type': 'application/json',
    };
  }

  // ── Device sync ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> syncDevice(Map<String, dynamic> payload) async {
    return _withRetry(() async {
      try {
        const path = '/api/sync';
        final res = await _client.post(
          Uri.parse(Environment.apiSyncUrl),
          headers: await _postHeaders(path),
          body: jsonEncode(payload),
        ).timeout(_timeout);
        if (res.statusCode != 200) return null;
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[ApiService] syncDevice failed: $e');
        return null;
      }
    });
  }

  Future<Map<String, dynamic>?> syncStatus(String deviceId) async {
    return _withRetry(() async {
      try {
        const path = '/api/sync';
        final res = await _client.get(
          Uri.parse('${Environment.apiSyncUrl}?device_id=$deviceId'),
          headers: await _getHeaders(path),
        ).timeout(_timeout);
        if (res.statusCode != 200) return null;
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[ApiService] syncStatus failed: $e');
        return null;
      }
    });
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> getHistory(String userId) async {
    return await _withRetry(() async {
      try {
        const path = '/api/history';
        final res = await _client.get(
          Uri.parse('${Environment.apiHistoryUrl}?user_id=$userId'),
          headers: await _getHeaders(path),
        ).timeout(_timeout);
        if (res.statusCode != 200) return <dynamic>[];
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['history'] as List<dynamic>? ?? <dynamic>[];
      } catch (e) {
        debugPrint('[ApiService] getHistory failed: $e');
        return <dynamic>[];
      }
    }) ?? [];
  }

  Future<void> addHistory(Map<String, dynamic> entry) async {
    try {
      const path = '/api/history';
      await _client.post(
        Uri.parse(Environment.apiHistoryUrl),
        headers: await _postHeaders(path),
        body: jsonEncode(entry),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] addHistory failed: $e');
    }
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getPlaylists(String userId) async {
    return await _withRetry(() async {
      try {
        const path = '/api/playlists';
        final res = await _client.get(
          Uri.parse('${Environment.apiPlaylistsUrl}?user_id=$userId'),
          headers: await _getHeaders(path),
        ).timeout(_timeout);
        if (res.statusCode != 200) return <dynamic>[];
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['playlists'] as List<dynamic>? ?? <dynamic>[];
      } catch (e) {
        debugPrint('[ApiService] getPlaylists failed: $e');
        return <dynamic>[];
      }
    }) ?? [];
  }

  Future<void> savePlaylist(Map<String, dynamic> playlist) async {
    try {
      const path = '/api/playlists';
      await _client.post(
        Uri.parse(Environment.apiPlaylistsUrl),
        headers: await _postHeaders(path),
        body: jsonEncode(playlist),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] savePlaylist failed: $e');
    }
  }

  Future<void> deletePlaylist(String playlistId, String userId) async {
    try {
      const path = '/api/playlists';
      await _client.delete(
        Uri.parse('${Environment.apiPlaylistsUrl}?id=$playlistId&user_id=$userId'),
        headers: await _getHeaders(path),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] deletePlaylist failed: $e');
    }
  }

  // ── Pro status ────────────────────────────────────────────────────────────

  Future<int> getProStatus(String userId) async {
    return await _withRetry(() async {
      try {
        const path = '/api/pro';
        final res = await _client.get(
          Uri.parse('${Environment.apiProUrl}?user_id=$userId'),
          headers: await _getHeaders(path),
        ).timeout(_timeout);
        if (res.statusCode != 200) return 0;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['expiry_ms'] as num?)?.toInt() ?? 0;
      } catch (e) {
        debugPrint('[ApiService] getProStatus failed: $e');
        return 0;
      }
    }) ?? 0;
  }

  // ── Feedback ──────────────────────────────────────────────────────────────

  Future<void> submitFeedback(Map<String, dynamic> feedback) async {
    try {
      const path = '/api/feedback';
      await _client.post(
        Uri.parse(Environment.apiFeedbackUrl),
        headers: await _postHeaders(path),
        body: jsonEncode(feedback),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] submitFeedback failed: $e');
    }
  }

  // ── Crash reports ─────────────────────────────────────────────────────────

  Future<void> submitCrashReport(Map<String, dynamic> report) async {
    try {
      const path = '/api/crash-report';
      await _client.post(
        Uri.parse(Environment.apiCrashUrl),
        headers: await _postHeaders(path),
        body: jsonEncode(report),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] submitCrashReport failed: $e');
    }
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getBookmarks(String userId) async {
    try {
      const path = '/api/bookmarks';
      final res = await _client.get(
        Uri.parse('${Environment.workerUrl}/api/bookmarks?user_id=$userId'),
        headers: await _getHeaders(path),
      ).timeout(_timeout);
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['bookmarks'] as List<dynamic>? ?? [];
    } catch (e) {
      debugPrint('[ApiService] getBookmarks failed: $e');
      return [];
    }
  }

  Future<void> saveBookmark(Map<String, dynamic> bookmark) async {
    try {
      const path = '/api/bookmarks';
      await _client.post(
        Uri.parse('${Environment.workerUrl}/api/bookmarks'),
        headers: await _postHeaders(path),
        body: jsonEncode(bookmark),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] saveBookmark failed: $e');
    }
  }

  Future<void> deleteBookmark(String bookmarkId, String userId) async {
    try {
      const path = '/api/bookmarks';
      await _client.delete(
        Uri.parse('${Environment.workerUrl}/api/bookmarks?id=$bookmarkId&user_id=$userId'),
        headers: await _getHeaders(path),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] deleteBookmark failed: $e');
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the underlying HTTP client and releases the connection pool.
  /// Call this from the app's dispose lifecycle (e.g. in main.dart or a
  /// top-level provider's onDispose callback).
  void dispose() {
    _client.close();
  }

  // ── EQ presets ────────────────────────────────────────────────────────────

  Future<List<dynamic>> getEqPresets(String userId) async {
    try {
      const path = '/api/equalizer';
      final res = await _client.get(
        Uri.parse('${Environment.workerUrl}/api/equalizer?user_id=$userId'),
        headers: await _getHeaders(path),
      ).timeout(_timeout);
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['presets'] as List<dynamic>? ?? [];
    } catch (e) {
      debugPrint('[ApiService] getEqPresets failed: $e');
      return [];
    }
  }

  Future<void> saveEqPreset(Map<String, dynamic> preset) async {
    try {
      const path = '/api/equalizer';
      await _client.post(
        Uri.parse('${Environment.workerUrl}/api/equalizer'),
        headers: await _postHeaders(path),
        body: jsonEncode(preset),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] saveEqPreset failed: $e');
    }
  }

  Future<void> deleteEqPreset(String presetId, String userId) async {
    try {
      const path = '/api/equalizer';
      await _client.delete(
        Uri.parse('${Environment.workerUrl}/api/equalizer?id=$presetId&user_id=$userId'),
        headers: await _getHeaders(path),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] deleteEqPreset failed: $e');
    }
  }
}
