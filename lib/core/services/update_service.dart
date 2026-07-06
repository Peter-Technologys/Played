import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Checks if a newer version of OTYA Player is available.
///
/// Reads version.json from the Cloudflare Worker — updated automatically
/// every time a new release is published. No manual changes needed.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // The Worker endpoint — returns { version, date } JSON
  static const String _versionUrl =
      'https://getotya.download.apk.petersmartlink.com/version';

  // The smart download page — picks the right APK for the user's phone
  static const String _downloadUrl =
      'https://petersmartlink.com/download/otya-player';

  static const String _prefLastCheck = 'update_last_check';
  static const String _prefSkippedVersion = 'update_skipped_version';

  String get downloadUrl => _downloadUrl;

  /// Returns [UpdateInfo] if a newer version is available, null otherwise.
  /// Checks at most once per day to avoid hammering the server.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Throttle: only check once per day unless forced
      if (!force) {
        final lastCheck = prefs.getInt(_prefLastCheck) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastCheck < const Duration(hours: 24).inMilliseconds) {
          return null;
        }
      }

      // Fetch version info from Cloudflare Worker
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['version'] as String? ?? '';
      if (latestVersion.isEmpty) return null;

      // Save the time we last checked
      await prefs.setInt(
          _prefLastCheck, DateTime.now().millisecondsSinceEpoch);

      // Compare with the installed version
      const installedVersion = '1.2.0'; // matches pubspec.yaml version
      if (!_isNewer(latestVersion, installedVersion)) return null;

      // Check if user already said "remind me later" for this version
      final skipped = prefs.getString(_prefSkippedVersion) ?? '';
      if (skipped == latestVersion) return null;

      return UpdateInfo(
        latestVersion: latestVersion,
        releaseDate: data['date'] as String? ?? '',
        downloadUrl: _downloadUrl,
      );
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
      return null;
    }
  }

  /// User tapped "Remind me later" — skip this version until next app open.
  Future<void> remindLater(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSkippedVersion, version);
  }

  /// Compares two version strings like "1.2.0" and "1.3.0".
  bool _isNewer(String latest, String installed) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final i = installed.split('.').map(int.parse).toList();
      for (var idx = 0; idx < 3; idx++) {
        final lv = idx < l.length ? l[idx] : 0;
        final iv = idx < i.length ? i[idx] : 0;
        if (lv > iv) return true;
        if (lv < iv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class UpdateInfo {
  final String latestVersion;
  final String releaseDate;
  final String downloadUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.releaseDate,
    required this.downloadUrl,
  });
}
