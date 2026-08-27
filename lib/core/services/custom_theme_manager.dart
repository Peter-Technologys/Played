import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'online_theme_service.dart';

/// Offline-first visual theme manager.
///
/// A user photo or a tiny online story-theme manifest is stored in app-owned
/// storage. No network connection is required after a story theme is installed.
class CustomThemeManager extends ChangeNotifier {
  CustomThemeManager._();
  static final CustomThemeManager instance = CustomThemeManager._();

  static const String _settingsFile = 'otya_theme_settings.json';
  String? _wallpaperPath;
  String _themeId = 'otya-midnight';
  double _artOpacity = 0.55;
  double _artBlur = 0;
  Map<String, dynamic>? _storyTheme;

  String? get wallpaperPath => _wallpaperPath;
  String get themeId => _themeId;
  double get artOpacity => _artOpacity;
  double get artBlur => _artBlur;
  Map<String, dynamic>? get storyTheme => _storyTheme == null
      ? null
      : Map<String, dynamic>.unmodifiable(_storyTheme!);

  bool get _currentThemeWasAutoSeasonal =>
      _storyTheme?['seasonal'] is Map && _storyTheme?['autoAppliedSeasonal'] == true;

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final path = json['wallpaperPath'] as String?;
      _themeId = json['themeId'] as String? ?? 'otya-midnight';
      _artOpacity = (json['artOpacity'] as num?)?.toDouble() ?? 0.55;
      _artBlur = (json['artBlur'] as num?)?.toDouble() ?? 0;
      final story = json['storyTheme'];
      if (story is Map<String, dynamic>) _storyTheme = story;
      if (path != null && await File(path).exists()) _wallpaperPath = path;
      notifyListeners();
    } catch (e) {
      debugPrint('[ThemeManager] Load error: $e');
    }
  }

  Future<void> setTheme({
    required String id,
    String? artworkPath,
    double? opacity,
    double? blur,
  }) async {
    _themeId = id;
    _storyTheme = null;
    if (opacity != null) _artOpacity = opacity.clamp(0.0, 1.0);
    if (blur != null) _artBlur = blur.clamp(0.0, 24.0);
    if (artworkPath != null) await _copyArtwork(artworkPath);
    await _persist();
    notifyListeners();
  }

  Future<void> installOnlineTheme(
    OnlineTheme theme, {
    bool autoSeasonal = false,
  }) async {
    final manifest = theme.toJson();
    if (autoSeasonal) manifest['autoAppliedSeasonal'] = true;

    _themeId = theme.id;
    _storyTheme = manifest;
    _artOpacity = theme.overlay.clamp(0.18, 0.70);
    _artBlur = 0;
    _wallpaperPath = null;

    final imageUrl = theme.wallpaperUrl;
    if (imageUrl != null) {
      final uri = Uri.tryParse(imageUrl);
      if (uri != null && uri.scheme == 'https') {
        try {
          final response = await http.get(uri).timeout(const Duration(seconds: 12));
          final type = response.headers['content-type'] ?? '';
          if (response.statusCode == 200 &&
              response.bodyBytes.isNotEmpty &&
              response.bodyBytes.length <= 6 * 1024 * 1024 &&
              type.toLowerCase().startsWith('image/')) {
            final dir = await getApplicationDocumentsDirectory();
            final dest = Directory('${dir.path}/themes/${theme.id}');
            await dest.create(recursive: true);
            final out = File('${dest.path}/background.jpg');
            await out.writeAsBytes(response.bodyBytes, flush: true);
            _wallpaperPath = out.path;
          }
        } catch (e) {
          debugPrint('[ThemeManager] Image theme download skipped: $e');
        }
      }
    }

    await _persist();
    notifyListeners();
  }

  /// Checks the server catalog for an active event theme.
  ///
  /// Automatic event themes only replace the built-in default or a previous
  /// automatically-applied seasonal theme. A user photo or manually selected
  /// story theme is never overwritten.
  Future<void> refreshSeasonalTheme() async {
    final userHasWallpaper = _wallpaperPath != null;
    final userChoseNonSeasonalStory =
        _storyTheme != null && !_currentThemeWasAutoSeasonal;
    if (userHasWallpaper || userChoseNonSeasonalStory) return;

    try {
      final catalog = await OnlineThemeService.fetchCatalog();
      final active = OnlineThemeService.activeSeasonalTheme(catalog);
      if (active != null) {
        if (_themeId != active.id || !_currentThemeWasAutoSeasonal) {
          await installOnlineTheme(active, autoSeasonal: true);
        }
        return;
      }

      if (_currentThemeWasAutoSeasonal) {
        await useDefaultMountainTheme();
      }
    } catch (e) {
      // Seasonal switching must never block startup or offline playback.
      debugPrint('[ThemeManager] Seasonal refresh skipped: $e');
    }
  }

  Future<void> useDefaultMountainTheme() async {
    _themeId = 'otya-midnight';
    _storyTheme = null;
    _wallpaperPath = null;
    _artOpacity = 0.55;
    _artBlur = 0;
    await _persist();
    notifyListeners();
  }

  Future<void> setWallpaper(String sourcePath) async {
    _storyTheme = null;
    _themeId = 'otya-image';
    await _copyArtwork(sourcePath);
    await _persist();
    notifyListeners();
  }

  Future<void> _copyArtwork(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Not found', sourcePath);
    }
    final dir = await getApplicationDocumentsDirectory();
    final dest = Directory('${dir.path}/themes/$_themeId');
    await dest.create(recursive: true);
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final out = File('${dest.path}/background.$ext');
    await source.copy(out.path);
    _wallpaperPath = out.path;
  }

  Future<void> clearWallpaper() async {
    if (_wallpaperPath != null) {
      try {
        await File(_wallpaperPath!).delete();
      } catch (_) {}
      _wallpaperPath = null;
    }
    await _persist();
    notifyListeners();
  }

  DecorationImage? get wallpaperDecoration {
    final path = _wallpaperPath;
    if (path == null || !File(path).existsSync()) return null;
    return DecorationImage(
      image: FileImage(File(path)),
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: _artOpacity),
        BlendMode.darken,
      ),
    );
  }

  Future<void> _persist() async {
    try {
      await (await _file()).writeAsString(jsonEncode({
        'themeId': _themeId,
        'artOpacity': _artOpacity,
        'artBlur': _artBlur,
        if (_wallpaperPath != null) 'wallpaperPath': _wallpaperPath,
        if (_storyTheme != null) 'storyTheme': _storyTheme,
      }));
    } catch (e) {
      debugPrint('[ThemeManager] Persist error: $e');
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_settingsFile');
  }
}
