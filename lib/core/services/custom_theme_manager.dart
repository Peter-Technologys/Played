import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Manages a user-selected wallpaper image persisted to a local JSON file.
/// Pure Dart File I/O — no native plugin needed.
class CustomThemeManager extends ChangeNotifier {
  CustomThemeManager._();
  static final CustomThemeManager instance = CustomThemeManager._();

  static const String _settingsFile = 'otya_theme_settings.json';
  String? _wallpaperPath;
  String? get wallpaperPath => _wallpaperPath;

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final path = json['wallpaperPath'] as String?;
      if (path != null && await File(path).exists()) {
        _wallpaperPath = path;
        notifyListeners();
      }
    } catch (e) { debugPrint('[ThemeManager] Load error: $e'); }
  }

  Future<void> setWallpaper(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw FileSystemException('Not found', sourcePath);
    final dir  = await getApplicationDocumentsDirectory();
    final dest = Directory('${dir.path}/wallpapers');
    await dest.create(recursive: true);
    final ext  = sourcePath.split('.').last;
    final out  = File('${dest.path}/wallpaper.$ext');
    await source.copy(out.path);
    _wallpaperPath = out.path;
    await _persist();
    notifyListeners();
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
    if (_wallpaperPath == null) return null;
    return DecorationImage(
      image: FileImage(File(_wallpaperPath!)),
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.55), BlendMode.darken),
    );
  }

  Future<void> _persist() async {
    try {
      final data = <String, dynamic>{
        if (_wallpaperPath != null) 'wallpaperPath': _wallpaperPath,
      };
      await (await _file()).writeAsString(jsonEncode(data));
    } catch (e) { debugPrint('[ThemeManager] Persist error: $e'); }
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_settingsFile');
  }
}
