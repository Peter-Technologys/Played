import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

  Future<void> installOnlineTheme(OnlineTheme theme) async {
    // Story manifests are deliberately tiny. Persist the complete validated
    // manifest locally so the selected theme still renders with no internet.
    _themeId = theme.id;
    _storyTheme = theme.toJson();
    _artOpacity = theme.overlay.clamp(0.18, 0.70);
    _artBlur = 0;
    _wallpaperPath = null;
    await _persist();
    notifyListeners();
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
