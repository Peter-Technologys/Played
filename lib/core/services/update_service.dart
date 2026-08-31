import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import 'push_notification_service.dart';

/// Checks whether a newer version of OTYA is available.
/// Compares the server versionCode against the installed build number.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _prefLastCheck = 'update_last_check';

  bool _checkInProgress = false;

  String get downloadUrl => Environment.downloadUrl;

  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!Environment.selfUpdateEnabled) return null;
    if (_checkInProgress) return null;
    _checkInProgress = true;
    try {
      return await _doCheckForUpdate(force: force);
    } finally {
      _checkInProgress = false;
    }
  }

  Future<UpdateInfo?> _doCheckForUpdate({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!force) {
        final lastCheck = prefs.getInt(_prefLastCheck) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastCheck < const Duration(hours: 24).inMilliseconds) {
          debugPrint('[UpdateService] Skipping check — checked within 24h.');
          return null;
        }
      }

      http.Response? response;
      try {
        response = await http
            .get(Uri.parse(Environment.latestUrl))
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      if (response == null || response.statusCode != 200) {
        debugPrint('[UpdateService] /latest failed, trying /api/version fallback…');
        try {
          response = await http
              .get(Uri.parse(Environment.apiVersionUrl))
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
      }

      if (response == null || response.statusCode != 200) {
        debugPrint('[UpdateService] Both update endpoints failed.');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final serverVersionCode = (data['versionCode'] as num?)?.toInt() ?? 0;
      final serverVersion = data['version'] as String? ?? '';
      final changelog = data['changelog'] as String? ?? '';
      final rawDownloads = data['downloads'];
      final downloads = rawDownloads is Map<String, dynamic>
          ? rawDownloads
          : <String, dynamic>{};

      if (serverVersionCode == 0 || serverVersion.isEmpty) return null;

      await prefs.setInt(_prefLastCheck, DateTime.now().millisecondsSinceEpoch);

      final packageInfo = await PackageInfo.fromPlatform();
      final installedCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint(
        '[UpdateService] Installed: $installedCode  Server: $serverVersionCode',
      );

      if (serverVersionCode <= installedCode) return null;

      final abi = _detectAbi();
      final directUrl = abi == 'arm64'
          ? (downloads['arm64'] as String? ?? Environment.arm64DownloadUrl)
          : (downloads['arm32'] as String? ?? Environment.arm32DownloadUrl);

      return UpdateInfo(
        version: serverVersion,
        versionCode: serverVersionCode,
        installedCode: installedCode,
        changelog: changelog,
        downloadUrl:
            downloads['auto'] as String? ?? Environment.downloadUrl,
        directUrl: directUrl,
        releaseDate: data['date'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
      return null;
    }
  }

  Future<void> checkAndNotify() async {
    final info = await checkForUpdate();
    if (info == null) return;

    await PushNotificationService.instance.showUpdateNotification(
      version: info.version,
      releaseNotes: info.changelog,
      downloadUrl: info.downloadUrl,
    );
  }

  /// Defer this update prompt. The regular 24-hour check window remains the
  /// authority, so choosing Later never suppresses the same release forever.
  Future<void> remindLater(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLastCheck, DateTime.now().millisecondsSinceEpoch);
    debugPrint('[UpdateService] Remind later for build $versionCode.');
  }

  String _detectAbi() => Environment.appArch;
}

class UpdateInfo {
  final String version;
  final int versionCode;
  final int installedCode;
  final String changelog;
  final String downloadUrl;
  final String directUrl;
  final String releaseDate;

  const UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.installedCode,
    required this.changelog,
    required this.downloadUrl,
    required this.directUrl,
    required this.releaseDate,
  });
}
