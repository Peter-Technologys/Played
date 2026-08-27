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
    this.seasonal,
  });

  final String id;
  final String name;
  final String story;
  final String scene;
  final int version;
  final double overlay;
  final Map<String, String> palette;
  final Map<String, dynamic>? seasonal;

  bool get isSeasonal => seasonal != null;
  bool get autoApply => seasonal?['autoApply'] == true;
  int get seasonalPriority => (seasonal?['priority'] as num?)?.toInt() ?? 0;

  bool isActiveOn(DateTime date) {
    final start = seasonal?['start'] as String?;
    final end = seasonal?['end'] as String?;
    if (start == null || end == null) return false;

    DateTime? parseMonthDay(String value, int year) {
      final parts = value.split('-');
      if (parts.length != 2) return null;
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      if (month == null || day == null) return null;
      return DateTime(year, month, day);
    }

    final startThisYear = parseMonthDay(start, date.year);
    final endThisYear = parseMonthDay(end, date.year);
    if (startThisYear == null || endThisYear == null) return false;

    final today = DateTime(date.year, date.month, date.day);
    if (!endThisYear.isBefore(startThisYear)) {
      return !today.isBefore(startThisYear) && !today.isAfter(endThisYear);
    }

    // Window crosses New Year, e.g. Dec 27 → Jan 7.
    if (today.month >= startThisYear.month) {
      final endNextYear = parseMonthDay(end, date.year + 1)!;
      return !today.isBefore(startThisYear) && !today.isAfter(endNextYear);
    }
    final startPreviousYear = parseMonthDay(start, date.year - 1)!;
    return !today.isBefore(startPreviousYear) && !today.isAfter(endThisYear);
  }

  factory OnlineTheme.fromJson(Map<String, dynamic> json) {
    final rawPalette = json['palette'] as Map<String, dynamic>? ?? const {};
    final rawSeasonal = json['seasonal'];
    return OnlineTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      story: json['story'] as String? ?? '',
      scene: json['scene'] as String? ?? 'mountain_lake',
      version: (json['version'] as num?)?.toInt() ?? 1,
      overlay: (json['overlay'] as num?)?.toDouble() ?? 0.38,
      palette: rawPalette.map((key, value) => MapEntry(key, value.toString())),
      seasonal: rawSeasonal is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawSeasonal)
          : null,
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
        if (seasonal != null) 'seasonal': seasonal,
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

  static OnlineTheme? activeSeasonalTheme(
    List<OnlineTheme> themes, {
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final active = themes
        .where((theme) => theme.isSeasonal && theme.autoApply && theme.isActiveOn(date))
        .toList()
      ..sort((a, b) => b.seasonalPriority.compareTo(a.seasonalPriority));
    return active.isEmpty ? null : active.first;
  }
}
