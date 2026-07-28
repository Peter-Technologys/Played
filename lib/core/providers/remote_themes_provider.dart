// lib/core/providers/remote_themes_provider.dart
//
// Fetches the list of available server themes from GET /api/themes.
// Caches the result in SharedPreferences so the list is available offline.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import '../services/api_signer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RemoteTheme — data class
// ─────────────────────────────────────────────────────────────────────────────

class RemoteTheme {
  final String id;
  final String key;
  final String uploaded;

  const RemoteTheme({
    required this.id,
    required this.key,
    required this.uploaded,
  });

  factory RemoteTheme.fromJson(Map<String, dynamic> json) {
    return RemoteTheme(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      uploaded: json['uploaded'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'uploaded': uploaded,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// RemoteThemesNotifier — AsyncNotifier
// ─────────────────────────────────────────────────────────────────────────────

class RemoteThemesNotifier extends AsyncNotifier<List<RemoteTheme>> {
  static const _kCacheKey = 'otya_themes_list_cache';

  @override
  Future<List<RemoteTheme>> build() async {
    // Offline-first: serve cached themes immediately so the section appears
    // instantly without a loading flash. Then refresh in the background and
    // update state if fresh data arrives.
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      // ignore: unawaited_futures
      Future(_backgroundRefresh); // fire-and-forget
      return cached;
    }
    // No cache at all — full blocking fetch (loading state until resolved).
    return _fetchThemes();
  }

  /// Fetches fresh themes from the network and updates provider state if
  /// successful. Runs after cached data has already been returned to the UI.
  Future<void> _backgroundRefresh() async {
    try {
      final headers = ApiSigner.signedHeaders(
        method: 'GET',
        path: '/api/themes',
      );
      final response = await http
          .get(Uri.parse(Environment.apiThemesUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['themes'] as List<dynamic>? ?? [];
        final themes = rawList
            .whereType<Map<String, dynamic>>()
            .map(RemoteTheme.fromJson)
            .toList();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _kCacheKey,
            jsonEncode(themes.map((t) => t.toJson()).toList()),
          );
        } catch (_) {}
        try { state = AsyncValue.data(themes); } catch (_) {}
      }
    } catch (e) {
      debugPrint('[RemoteThemesProvider] Background refresh failed: $e');
    }
  }

  Future<List<RemoteTheme>> _fetchThemes() async {
    try {
      final headers = ApiSigner.signedHeaders(
        method: 'GET',
        path: '/api/themes',
      );
      final response = await http
          .get(Uri.parse(Environment.apiThemesUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['themes'] as List<dynamic>? ?? [];
        final themes = rawList
            .whereType<Map<String, dynamic>>()
            .map(RemoteTheme.fromJson)
            .toList();

        // Persist to cache
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _kCacheKey,
            jsonEncode(themes.map((t) => t.toJson()).toList()),
          );
        } catch (e) {
          debugPrint('[RemoteThemesProvider] Cache write error: $e');
        }

        return themes;
      }

      debugPrint(
          '[RemoteThemesProvider] Unexpected status ${response.statusCode}');
      return await _loadFromCache();
    } catch (e) {
      debugPrint('[RemoteThemesProvider] Fetch error: $e');
      return await _loadFromCache();
    }
  }

  Future<List<RemoteTheme>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kCacheKey);
      if (cached != null) {
        final rawList = jsonDecode(cached) as List<dynamic>;
        return rawList
            .whereType<Map<String, dynamic>>()
            .map(RemoteTheme.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('[RemoteThemesProvider] Cache read error: $e');
    }
    return [];
  }

  /// Force a fresh fetch (e.g. on retry button tap).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchThemes);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final remoteThemesProvider =
    AsyncNotifierProvider<RemoteThemesNotifier, List<RemoteTheme>>(
  RemoteThemesNotifier.new,
);
