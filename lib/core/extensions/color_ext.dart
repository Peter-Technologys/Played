import 'package:flutter/material.dart';

/// Extension that adds hex-string parsing to [Color].
///
/// Supports:
///   '#RGB'       → 3-digit shorthand (e.g. '#F00' → red)
///   '#RRGGBB'    → 6-digit (e.g. '#E50914')
///   '#AARRGGBB'  → 8-digit with alpha (e.g. '#CCE50914')
///   Without '#'  → all of the above without the hash prefix
///
/// Every parse failure returns [defaultColor] so the app never crashes
/// on a malformed server response.
extension HexColor on Color {
  /// Parses [hexString] into a [Color].
  ///
  /// [defaultColor] is returned when parsing fails.
  /// Defaults to opaque black so a bad server value is always visible.
  static Color fromHex(
    String? hexString, {
    Color defaultColor = Colors.black,
  }) {
    if (hexString == null || hexString.isEmpty) return defaultColor;

    try {
      // Strip leading '#' and any surrounding whitespace.
      final clean = hexString.trim().replaceFirst('#', '');

      switch (clean.length) {
        case 3:
          // Shorthand RGB: 'F00' → 'FFFF0000'
          final r = clean[0] * 2;
          final g = clean[1] * 2;
          final b = clean[2] * 2;
          return Color(int.parse('FF$r$g$b', radix: 16));

        case 6:
          // Standard RRGGBB — prepend full-opacity alpha.
          return Color(int.parse('FF$clean', radix: 16));

        case 8:
          // AARRGGBB — alpha already included.
          return Color(int.parse(clean, radix: 16));

        default:
          return defaultColor;
      }
    } catch (_) {
      return defaultColor;
    }
  }
}
