import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'http_client.dart';
import 'online_theme_service.dart';

/// Offline-first visual theme manager.
///
/// A user photo or an online story-theme manifest/image is copied into
/// app-owned storage. No network connection is required after installation.
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
  bool get hasImageWallpaper {
    final path = _wallpaperPath;
    return path != null && File(path).existsSync();
  }

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
      _artOpacity = ((json['artOpacity'] as num?)?.toDouble() ?? 0.55).clamp(0.0, 1.0);
      _artBlur = ((json['artBlur'] as num?)?.toDouble() ?? 0).clamp(0.0, 24.0);
      final story = json['storyTheme'];
      if (story is Map<String, dynamic>) _storyTheme = story;
      if (path != null && await File(path).exists()) {
        _wallpaperPath = path;
      } else if (path != null) {
        // Do not keep a dead file path after restore/storage cleanup. Falling
        // back to the story/default background is safer than a blank screen.
        _wallpaperPath = null;
        if (_themeId == 'otya-image') _themeId = 'otya-midnight';
        await _persist();
      }
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
          final response = await AppHttpClient.instance.client
              .get(uri, headers: const {'Accept': 'image/*'})
              .timeout(const Duration(seconds: 12));
          final type = (response.headers['content-type'] ?? '').toLowerCase();
          if (response.statusCode == 200 &&
              response.bodyBytes.isNotEmpty &&
              response.bodyBytes.length <= 6 * 1024 * 1024 &&
              type.startsWith('image/')) {
            final dir = await getApplicationDocumentsDirectory();
            final dest = Directory('${dir.path}/themes/${theme.id}');
            await dest.create(recursive: true);
            final extension = switch (type.split(';').first.trim()) {
              'image/png' => 'png',
              'image/webp' => 'webp',
              'image/jpeg' || 'image/jpg' => 'jpg',
              _ => 'img',
            };
            final out = File('${dest.path}/background.$extension');
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
    final userHasWallpaper = hasImageWallpaper;
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
    final length = await source.length();
    if (length <= 0 || length > 20 * 1024 * 1024) {
      throw FileSystemException('Unsupported wallpaper size', sourcePath);
    }

    final dir = await getApplicationDocumentsDirectory();
    final dest = Directory('${dir.path}/themes/$_themeId');
    await dest.create(recursive: true);
    final rawExt = sourcePath.contains('.') ? sourcePath.split('.').last.toLowerCase() : 'jpg';
    final ext = const {'jpg', 'jpeg', 'png', 'webp'}.contains(rawExt) ? rawExt : 'jpg';
    final out = File('${dest.path}/background.$ext');

    // Copy through a temporary file so an interrupted write cannot destroy the
    // currently selected background.
    final temp = File('${out.path}.tmp');
    if (await temp.exists()) await temp.delete();
    await source.copy(temp.path);
    if (await out.exists()) await out.delete();
    await temp.rename(out.path);
    _wallpaperPath = out.path;
  }

  Future<void> clearWallpaper() async {
    final oldPath = _wallpaperPath;
    _wallpaperPath = null;
    if (_themeId == 'otya-image') _themeId = 'otya-midnight';
    await _persist();
    notifyListeners();

    if (oldPath != null) {
      try {
        final file = File(oldPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  DecorationImage? get wallpaperDecoration {
    final path = _wallpaperPath;
    if (path == null || !File(path).existsSync()) return null;
    return DecorationImage(
      image: FileImage(File(path)),
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: _artOpacity.clamp(0.0, 1.0)),
        BlendMode.darken,
      ),
    );
  }

  Future<void> _persist() async {
    try {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      final payload = jsonEncode({
        'themeId': _themeId,
        'artOpacity': _artOpacity,
        'artBlur': _artBlur,
        if (_wallpaperPath != null) 'wallpaperPath': _wallpaperPath,
        if (_storyTheme != null) 'storyTheme': _storyTheme,
      });
      await temp.writeAsString(payload, flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('[ThemeManager] Persist error: $e');
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_settingsFile');
  }
}
