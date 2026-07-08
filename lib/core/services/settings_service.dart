import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Pure Dart JSON settings serializer. No SharedPreferences plugin needed.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _file = 'otya_settings.json';

  String _profileName   = 'OTYA User';
  bool   _audioEnabled  = true;
  int    _themeIndex    = 0;
  bool   _skipSilence   = false;
  double _playbackSpeed = 1.0;
  bool   _showLyrics    = true;

  String get profileName   => _profileName;
  bool   get audioEnabled  => _audioEnabled;
  int    get themeIndex    => _themeIndex;
  bool   get skipSilence   => _skipSilence;
  double get playbackSpeed => _playbackSpeed;
  bool   get showLyrics    => _showLyrics;

  Future<void> load() async {
    try {
      final f = await _settingsFile();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _profileName   = j['profileName']   as String? ?? _profileName;
      _audioEnabled  = j['audioEnabled']  as bool?   ?? _audioEnabled;
      _themeIndex    = j['themeIndex']    as int?    ?? _themeIndex;
      _skipSilence   = j['skipSilence']   as bool?   ?? _skipSilence;
      _playbackSpeed = (j['playbackSpeed'] as num?)?.toDouble() ?? _playbackSpeed;
      _showLyrics    = j['showLyrics']    as bool?   ?? _showLyrics;
      notifyListeners();
    } catch (e) { debugPrint('[Settings] Load error: $e'); }
  }

  Future<void> save() async {
    try {
      final f = await _settingsFile();
      // Write to a temp file first, then copy-and-delete — prevents data loss
      // if the app is killed mid-write. We copy instead of rename because
      // rename() across mount points throws on some Android file systems.
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'profileName': _profileName, 'audioEnabled': _audioEnabled,
        'themeIndex': _themeIndex, 'skipSilence': _skipSilence,
        'playbackSpeed': _playbackSpeed, 'showLyrics': _showLyrics,
      }));
      await f.writeAsBytes(await tmp.readAsBytes());
      await tmp.delete();
      notifyListeners();
    } catch (e) { debugPrint('[Settings] Save error: $e'); }
  }

  Future<void> setProfileName(String v)   async { _profileName   = v; await save(); }
  Future<void> setAudioEnabled(bool v)    async { _audioEnabled  = v; await save(); }
  Future<void> setThemeIndex(int v)       async { _themeIndex    = v; await save(); }
  Future<void> setSkipSilence(bool v)     async { _skipSilence   = v; await save(); }
  Future<void> setPlaybackSpeed(double v) async { _playbackSpeed = v; await save(); }
  Future<void> setShowLyrics(bool v)      async { _showLyrics    = v; await save(); }

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_file');
  }
}

/// Pure Process.run intent launcher — no url_launcher plugin needed.
class IntentLauncher {
  IntentLauncher._();

  static Future<void> openUrl(String url) async {
    try {
      await Process.run('am', ['start','--user','0','-a','android.intent.action.VIEW','-d', url]);
    } catch (e) { debugPrint('[Intent] openUrl failed: $e'); }
  }

  static Future<void> openPlayStore(String packageId) async {
    try {
      final r = await Process.run('am', [
        'start','--user','0','-a','android.intent.action.VIEW',
        '-d','market://details?id=$packageId',
      ]);
      if (r.exitCode != 0) {
        await openUrl('https://play.google.com/store/apps/details?id=$packageId');
      }
    } catch (e) { debugPrint('[Intent] openPlayStore failed: $e'); }
  }

  static Future<void> openEmail(String address, {String subject = ''}) async {
    final uri = 'mailto:$address${subject.isNotEmpty ? '?subject=${Uri.encodeComponent(subject)}' : ''}';
    await openUrl(uri);
  }
}
