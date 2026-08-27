import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OnlineTheme {
  const OnlineTheme({
    required this.id,
    required this.name,
    required this.story,
    required this.scene,
    required this.version,
    required this.overlay,
    required this.palette,
  });

  final String id;
  final String name;
  final String story;
  final String scene;
  final int version;
  final double overlay;
  final Map<String, String> palette;

  factory OnlineTheme.fromJson(Map<String, dynamic> json) {
    final rawPalette = json['palette'] as Map<String, dynamic>? ?? const {};
    return OnlineTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      story: json['story'] as String? ?? '',
      scene: json['scene'] as String? ?? 'mountain_lake',
      version: (json['version'] as num?)?.toInt() ?? 1,
      overlay: (json['overlay'] as num?)?.toDouble() ?? 0.38,
      palette: rawPalette.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'story': story,
        'scene': scene,
        'version': version,
        'overlay': overlay,
        'palette': palette,
      };
}

class OnlineThemeService {
  OnlineThemeService._();

  static const _catalogUrl = 'https://petersmartlink.com/api/themes';

  static Future<List<OnlineTheme>> fetchCatalog() async {
    try {
      final response = await http
          .get(Uri.parse(_catalogUrl), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        throw const FormatException('Theme catalog unavailable');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = decoded['themes'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(OnlineTheme.fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[OnlineThemeService] Catalog fetch failed: $e');
      rethrow;
    }
  }
}
