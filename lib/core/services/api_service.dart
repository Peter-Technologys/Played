// lib/core/services/api_service.dart
//
// Wraps all OTYA Backend API calls.
// Protected requests use the short-lived Bearer access token issued by
// OTYA Auth. No shared secret is embedded in the APK.

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'auth_service.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 12);

  Future<T?> _withRetry<T>(
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
        rethrow;
      }
      await Future<void>.delayed(delay);
      delay *= 2;
    }
    return null;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) return {'Accept': 'application/json'};
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, String>> _postHeaders() async {
    final token = await AuthService.instance.getValidToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, dynamic>?> syncDevice(Map<String, dynamic> payload) async {
    return _withRetry(() async {
      try {
        final res = await _client.post(
          Uri.parse(Environment.apiSyncUrl),
          headers: await _postHeaders(),
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
        final res = await _client.get(
          Uri.parse('${Environment.apiSyncUrl}?device_id=${Uri.encodeQueryComponent(deviceId)}'),
          headers: await _getHeaders(),
        ).timeout(_timeout);
        if (res.statusCode != 200) return null;
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[ApiService] syncStatus failed: $e');
        return null;
      }
    });
  }

  Future<List<dynamic>> getHistory(String userId) async {
    return await _withRetry(() async {
      try {
        final res = await _client.get(
          Uri.parse('${Environment.apiHistoryUrl}?user_id=${Uri.encodeQueryComponent(userId)}'),
          headers: await _getHeaders(),
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
      await _client.post(
        Uri.parse(Environment.apiHistoryUrl),
        headers: await _postHeaders(),
        body: jsonEncode(entry),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] addHistory failed: $e');
    }
  }

  Future<List<dynamic>> getPlaylists(String userId) async {
    return await _withRetry(() async {
      try {
        final res = await _client.get(
          Uri.parse('${Environment.apiPlaylistsUrl}?user_id=${Uri.encodeQueryComponent(userId)}'),
          headers: await _getHeaders(),
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
      await _client.post(
        Uri.parse(Environment.apiPlaylistsUrl),
        headers: await _postHeaders(),
        body: jsonEncode(playlist),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] savePlaylist failed: $e');
    }
  }

  Future<void> deletePlaylist(String playlistId, String userId) async {
    try {
      await _client.delete(
        Uri.parse('${Environment.apiPlaylistsUrl}?id=${Uri.encodeQueryComponent(playlistId)}&user_id=${Uri.encodeQueryComponent(userId)}'),
        headers: await _getHeaders(),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] deletePlaylist failed: $e');
    }
  }

  Future<int> getProStatus(String userId) async {
    return await _withRetry(() async {
      try {
        final res = await _client.get(
          Uri.parse('${Environment.apiProUrl}?user_id=${Uri.encodeQueryComponent(userId)}'),
          headers: await _getHeaders(),
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

  Future<void> submitFeedback(Map<String, dynamic> feedback) async {
    try {
      await _client.post(
        Uri.parse(Environment.apiFeedbackUrl),
        headers: await _postHeaders(),
        body: jsonEncode(feedback),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] submitFeedback failed: $e');
    }
  }

  Future<void> submitCrashReport(Map<String, dynamic> report) async {
    try {
      await _client.post(
        Uri.parse(Environment.apiCrashUrl),
        headers: await _postHeaders(),
        body: jsonEncode(report),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] submitCrashReport failed: $e');
    }
  }

  Future<List<dynamic>> getBookmarks(String userId) async {
    try {
      final res = await _client.get(
        Uri.parse('${Environment.workerUrl}/api/bookmarks?user_id=${Uri.encodeQueryComponent(userId)}'),
        headers: await _getHeaders(),
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
      await _client.post(
        Uri.parse('${Environment.workerUrl}/api/bookmarks'),
        headers: await _postHeaders(),
        body: jsonEncode(bookmark),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] saveBookmark failed: $e');
    }
  }

  Future<void> deleteBookmark(String bookmarkId, String userId) async {
    try {
      await _client.delete(
        Uri.parse('${Environment.workerUrl}/api/bookmarks?id=${Uri.encodeQueryComponent(bookmarkId)}&user_id=${Uri.encodeQueryComponent(userId)}'),
        headers: await _getHeaders(),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] deleteBookmark failed: $e');
    }
  }

  void dispose() => _client.close();

  Future<List<dynamic>> getEqPresets(String userId) async {
    try {
      final res = await _client.get(
        Uri.parse('${Environment.workerUrl}/api/equalizer?user_id=${Uri.encodeQueryComponent(userId)}'),
        headers: await _getHeaders(),
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
      await _client.post(
        Uri.parse('${Environment.workerUrl}/api/equalizer'),
        headers: await _postHeaders(),
        body: jsonEncode(preset),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] saveEqPreset failed: $e');
    }
  }

  Future<void> deleteEqPreset(String presetId, String userId) async {
    try {
      await _client.delete(
        Uri.parse('${Environment.workerUrl}/api/equalizer?id=${Uri.encodeQueryComponent(presetId)}&user_id=${Uri.encodeQueryComponent(userId)}'),
        headers: await _getHeaders(),
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService] deleteEqPreset failed: $e');
    }
  }
}
