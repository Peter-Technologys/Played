import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../extensions/color_ext.dart';
import '../config/environment.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeProvider
//
// Fetches the v2 dynamic theme from the Cloudflare Worker at
// petersmartlink.com/configs/theme and exposes it as a [ThemeData] that
// MaterialApp can consume directly.
//
// Features:
//   • Loads cached theme instantly on startup (no blank flash)
//   • ETag-aware HTTP — sends If-None-Match, handles 304 Not Modified
//   • Parses v2 schema: colors, component_overrides, card_border_radius,
//     google_font_family, button_padding, is_dark_mode
//   • Exposes [announcement] so the app can show a one-time dialog
//   • Falls back to AppTheme.dark if network is unavailable
//   • ChangeNotifier — call notifyListeners() triggers a full theme rebuild
// ─────────────────────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _kThemeCache = 'otya_cached_theme_v2';
  static const String _kEtag       = 'otya_theme_etag_v2';
  static const String _kSeenAnnouncements = 'otya_seen_announcements';

  // ── Singleton ─────────────────────────────────────────────────────────────
  ThemeProvider._();
  static final ThemeProvider instance = ThemeProvider._();

  // ── State ─────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _themeData;
  bool _fetchInProgress = false;

  /// Raw theme map — useful for reading custom fields not exposed as getters.
  Map<String, dynamic>? get rawTheme => _themeData;

  /// True when a remote theme has been loaded (cached or fresh).
  bool get hasTheme => _themeData != null;

  // ── Announcement ──────────────────────────────────────────────────────────

  /// Returns the announcement block if [show_dialog] is true AND the user
  /// has not already dismissed this announcement ID.
  /// Returns null if there is nothing to show.
  Future<OtyaAnnouncement?> pendingAnnouncement() async {
    final raw = _themeData?['announcement'] as Map<String, dynamic>?;
    if (raw == null) return null;

    final showDialog = raw['show_dialog'] as bool? ?? false;
    if (!showDialog) return null;

    final id = raw['id'] as String? ?? '';
    if (id.isEmpty) return null;

    // Check if already seen
    final prefs = await SharedPreferences.getInstance();
    final seen  = prefs.getStringList(_kSeenAnnouncements) ?? [];
    if (seen.contains(id)) return null;

    return OtyaAnnouncement(
      id:         id,
      title:      raw['title']       as String? ?? '',
      message:    raw['message']     as String? ?? '',
      buttonText: raw['button_text'] as String? ?? 'OK',
    );
  }

  /// Call this after the user dismisses an announcement so it never shows again.
  Future<void> markAnnouncementSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final seen  = prefs.getStringList(_kSeenAnnouncements) ?? [];
    if (!seen.contains(id)) {
      seen.add(id);
      await prefs.setStringList(_kSeenAnnouncements, seen);
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Call once from main() or app.dart initState().
  /// Loads cache instantly, then fetches remote update in the background.
  Future<void> initTheme() async {
    await _loadFromCache();
    // Fire-and-forget — never blocks startup
    fetchRemoteTheme().ignore();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs      = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kThemeCache);
      if (cachedJson != null) {
        final parsed = jsonDecode(cachedJson) as Map<String, dynamic>?;
        if (parsed != null) {
          _themeData = parsed;
          notifyListeners();
          debugPrint('[ThemeProvider] Loaded from cache.');
        }
      }
    } catch (e) {
      debugPrint('[ThemeProvider] Cache load error: $e');
    }
  }

  // ── Remote fetch ──────────────────────────────────────────────────────────

  Future<void> fetchRemoteTheme() async {
    if (_fetchInProgress) return;
    _fetchInProgress = true;
    try {
      await _doFetch();
    } catch (e) {
      debugPrint('[ThemeProvider] fetchRemoteTheme error: $e');
    } finally {
      _fetchInProgress = false;
    }
  }

  Future<void> _doFetch() async {
    final prefs     = await SharedPreferences.getInstance();
    final savedEtag = prefs.getString(_kEtag);

    final response = await http.get(
      Uri.parse(Environment.configsThemeUrl),
      headers: {
        'Accept': 'application/json',
        if (savedEtag != null) 'If-None-Match': savedEtag,
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 304) {
      // Nothing changed — keep current theme
      debugPrint('[ThemeProvider] 304 Not Modified — theme unchanged.');
      return;
    }

    if (response.statusCode == 200) {
      // Validate JSON before persisting
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        debugPrint('[ThemeProvider] Invalid JSON from server — ignoring.');
        return;
      }

      _themeData = parsed;

      // Persist to cache
      await prefs.setString(_kThemeCache, response.body);
      final newEtag = response.headers['etag'];
      if (newEtag != null) await prefs.setString(_kEtag, newEtag);

      notifyListeners();
      debugPrint('[ThemeProvider] Remote theme applied: '
          '${parsed['theme_identity'] ?? 'unknown'}');
      return;
    }

    debugPrint('[ThemeProvider] Unexpected status ${response.statusCode}.');
  }

  // ── ThemeData builder ─────────────────────────────────────────────────────

  /// Returns a fully-built [ThemeData] from the current remote theme.
  /// Falls back to a sensible dark theme if no remote data is available.
  ThemeData get currentThemeData {
    final data = _themeData;
    if (data == null) return _fallback;

    final colors    = data['colors']              as Map<String, dynamic>? ?? {};
    final overrides = data['component_overrides'] as Map<String, dynamic>? ?? {};
    final isDark    = data['is_dark_mode']         as bool? ?? true;
    final fontFamily = data['google_font_family']  as String? ?? 'Inter';
    final cardRadius = (data['card_border_radius'] as num?)?.toDouble() ?? 16.0;
    final btnPadding = (data['button_padding']     as num?)?.toDouble() ?? 14.0;

    // ── Parse colors ────────────────────────────────────────────────────────
    final primary     = HexColor.fromHex(colors['primary']             as String?, defaultColor: const Color(0xFFE50914));
    final secondary   = HexColor.fromHex(colors['secondary']           as String?, defaultColor: const Color(0xFFB81D24));
    final background  = HexColor.fromHex(colors['scaffold_background'] as String?, defaultColor: const Color(0xFF141414));
    final surface     = HexColor.fromHex(colors['surface']             as String?, defaultColor: const Color(0xFF1F1F1F));
    final accent      = HexColor.fromHex(colors['accent']              as String?, defaultColor: const Color(0xFFFFD700));
    final error       = HexColor.fromHex(colors['error']               as String?, defaultColor: const Color(0xFFD32F2F));
    final textPrimary = HexColor.fromHex(colors['text_primary']        as String?, defaultColor: Colors.white);
    final textSecondary = HexColor.fromHex(colors['text_secondary']    as String?, defaultColor: const Color(0xFFB3B3B3));

    // ── Parse component overrides ────────────────────────────────────────────
    final appBarBg     = HexColor.fromHex(overrides['app_bar_background'] as String?, defaultColor: Colors.black);
    final cardBg       = HexColor.fromHex(overrides['card_background']    as String? ?? colors['surface'] as String?, defaultColor: surface);
    final navSelected  = HexColor.fromHex(overrides['nav_bar_selected']   as String? ?? colors['primary'] as String?, defaultColor: primary);
    final buttonText   = HexColor.fromHex(overrides['button_text']        as String?, defaultColor: Colors.white);

    final brightness = isDark ? Brightness.dark : Brightness.light;

    return ThemeData(
      useMaterial3:            true,
      brightness:              brightness,
      scaffoldBackgroundColor: background,
      fontFamily:              fontFamily,
      colorScheme: ColorScheme(
        brightness:  brightness,
        primary:     primary,
        onPrimary:   buttonText,
        secondary:   secondary,
        onSecondary: Colors.white,
        surface:     surface,
        onSurface:   textPrimary,
        error:       error,
        onError:     Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: textPrimary,
        elevation:       0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:     surface,
        selectedItemColor:   navSelected,
        unselectedItemColor: textSecondary,
        type:                BottomNavigationBarType.fixed,
        elevation:           0,
      ),
      cardTheme: CardThemeData(
        color:     cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: buttonText,
          elevation:       0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: btnPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      sliderTheme: SliderThemeData(
        trackHeight:        4,
        activeTrackColor:   accent,
        inactiveTrackColor: surface,
        thumbColor:         accent,
        overlayColor:       accent.withValues(alpha: 0.2),
      ),
      dividerTheme: DividerThemeData(
        color:     surface,
        thickness: 1,
        space:     0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(
          color:      textPrimary,
          fontFamily: fontFamily,
          fontSize:   13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior:  SnackBarBehavior.floating,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(cardRadius),
          ),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: BorderSide(color: surface),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: BorderSide(color: surface),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      splashColor:    accent.withValues(alpha: 0.06),
      highlightColor: accent.withValues(alpha: 0.04),
    );
  }

  // ── Fallback ──────────────────────────────────────────────────────────────

  /// Used when no remote or cached theme is available.
  /// Mirrors the static AppTheme.dark so the app always looks correct.
  ThemeData get _fallback => ThemeData(
    useMaterial3:            true,
    brightness:              Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F1117),
    fontFamily:              'Inter',
    colorScheme: const ColorScheme.dark(
      primary:   Color(0xFF00E5FF),
      secondary: Color(0xFF8B5CF6),
      surface:   Color(0xFF161B27),
      error:     Color(0xFFFF4D6A),
      onPrimary:   Colors.black,
      onSecondary: Colors.white,
      onSurface:   Color(0xFFF0F6FF),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OtyaAnnouncement
// ─────────────────────────────────────────────────────────────────────────────
class OtyaAnnouncement {
  final String id;
  final String title;
  final String message;
  final String buttonText;

  const OtyaAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.buttonText,
  });
}
