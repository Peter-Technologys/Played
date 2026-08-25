// lib/core/providers/remote_themes_provider.dart
//
// Previously fetched server themes from GET /api/themes.
// The /api/themes endpoint is not active; this provider returns an empty list.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
//
// The /api/themes endpoint is not active. Returns an empty list so the
// "More Themes" section is hidden gracefully without any network call.
// ─────────────────────────────────────────────────────────────────────────────

class RemoteThemesNotifier extends AsyncNotifier<List<RemoteTheme>> {
  @override
  Future<List<RemoteTheme>> build() async => const [];

  /// No-op refresh — endpoint not available.
  Future<void> refresh() async {
    state = const AsyncValue.data([]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final remoteThemesProvider =
    AsyncNotifierProvider<RemoteThemesNotifier, List<RemoteTheme>>(
  RemoteThemesNotifier.new,
);
