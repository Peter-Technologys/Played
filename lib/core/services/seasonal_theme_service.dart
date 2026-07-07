import 'package:flutter/material.dart';

class SeasonalThemeService {
  SeasonalThemeService._();
  static final SeasonalThemeService instance = SeasonalThemeService._();

  SeasonalTheme detect([DateTime? now]) {
    final d = now ?? DateTime.now();
    if (d.month == 12 && d.day <= 30)                        return SeasonalTheme.christmas;
    if ((d.month == 12 && d.day == 31) || (d.month == 1 && d.day == 1)) return SeasonalTheme.newYear;
    if ((d.month == 10 && d.day >= 15) || (d.month == 11 && d.day == 1)) return SeasonalTheme.halloween;
    return SeasonalTheme.defaultDark;
  }

  ThemeData themeData([DateTime? now]) => detect(now).toThemeData();
}

enum SeasonalTheme { christmas, halloween, newYear, defaultDark }

extension SeasonalThemeX on SeasonalTheme {
  Color get primary => switch (this) {
    SeasonalTheme.christmas   => const Color(0xFF1B5E20),
    SeasonalTheme.halloween   => const Color(0xFFE65100),
    SeasonalTheme.newYear     => const Color(0xFFFFD700),
    SeasonalTheme.defaultDark => const Color(0xFF00D4FF),
  };
  Color get secondary => switch (this) {
    SeasonalTheme.christmas   => const Color(0xFFB71C1C),
    SeasonalTheme.halloween   => const Color(0xFF212121),
    SeasonalTheme.newYear     => const Color(0xFF0D1B4B),
    SeasonalTheme.defaultDark => const Color(0xFF7C3AED),
  };
  Color get background => switch (this) {
    SeasonalTheme.christmas   => const Color(0xFF0A1A0A),
    SeasonalTheme.halloween   => const Color(0xFF0D0D0D),
    SeasonalTheme.newYear     => const Color(0xFF060B1A),
    SeasonalTheme.defaultDark => const Color(0xFF090D16),
  };
  String get label => switch (this) {
    SeasonalTheme.christmas   => '🎄 Christmas',
    SeasonalTheme.halloween   => '🎃 Halloween',
    SeasonalTheme.newYear     => '🎆 New Year',
    SeasonalTheme.defaultDark => '🌙 OTYA Dark',
  };
  ThemeData toThemeData() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
        primary: primary, secondary: secondary, surface: background),
    fontFamily: 'Inter',
  );
}
