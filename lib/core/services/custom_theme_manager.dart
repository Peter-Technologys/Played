import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Offline-first visual theme manager.
/// A theme is more than a color palette: it can contain local artwork and
/// presentation metadata. Artwork is copied into app-owned storage so it
/// remains available when the device has no internet connection.
class CustomThemeManager extends ChangeNotifier {
  CustomThemeManager._();
  static final CustomThemeManager instance = CustomThemeManager._();

  static const String _settingsFile = 'otya_theme_settings.json';
  String? _wallpaperPath;
  String _themeId = 'otya-midnight';
  double _artOpacity = 0.55;
  double _artBlur = 0;

  String? get wallpaperPath => _wallpaperPath;
  String get themeId => _themeId;
  double get artOpacity => _artOpacity;
  double get artBlur => _artBlur;

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final path = json['wallpaperPath'] as String?;
      _themeId = json['themeId'] as String? ?? 'otya-midnight';
      _artOpacity = (json['artOpacity'] as num?)?.toDouble() ?? 0.55;
      _artBlur = (json['artBlur'] as num?)?.toDouble() ?? 0;
      if (path != null && await File(path).exists()) _wallpaperPath = path;
      notifyListeners();
    } catch (e) { debugPrint('[ThemeManager] Load error: $e'); }
  }

  Future<void> setTheme({
    required String id,
    String? artworkPath,
    double? opacity,
    double? blur,
  }) async {
    _themeId = id;
    if (opacity != null) _artOpacity = opacity.clamp(0.0, 1.0);
    if (blur != null) _artBlur = blur.clamp(0.0, 24.0);
    if (artworkPath != null) await _copyArtwork(artworkPath);
    await _persist();
    notifyListeners();
  }

  Future<void> setWallpaper(String sourcePath) async {
    await _copyArtwork(sourcePath);
    await _persist();
    notifyListeners();
  }

  Future<void> _copyArtwork(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw FileSystemException('Not found', sourcePath);
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
      try { await File(_wallpaperPath!).delete(); } catch (_) {}
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
      }));
    } catch (e) { debugPrint('[ThemeManager] Persist error: $e'); }
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_settingsFile');
  }
}