import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../config/flavor_config.dart';
import 'api_signer.dart';
import 'update_notification_service.dart';

/// Checks if a newer version of OTYA Player is available.
/// Compares server versionCode against installed build number via package_info_plus.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _prefLastCheck   = 'update_last_check';
  static const String _prefSkippedCode = 'update_skipped_code';

  bool _checkInProgress = false;

  String get downloadUrl => Environment.downloadUrl;

  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!FlavorConfig.selfUpdateEnabled) return null;
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

      // /latest and /version are public (no HMAC) — used by website too
      http.Response? response;
      try {
        response = await http
            .get(Uri.parse(Environment.latestUrl))
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      if (response == null || response.statusCode != 200) {
        debugPrint('[UpdateService] /latest failed, trying /version fallback…');
        try {
          response = await http
              .get(Uri.parse(Environment.versionUrl))
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
      }

      if (response == null || response.statusCode != 200) {
        debugPrint('[UpdateService] Both endpoints failed.');
        return null;
      }

      final data              = jsonDecode(response.body) as Map<String, dynamic>;
      final serverVersionCode = (data['versionCode'] as num?)?.toInt() ?? 0;
      final serverVersion     = data['version']   as String? ?? '';
      final changelog         = data['changelog'] as String? ?? '';
      final rawDownloads      = data['downloads'];
      final downloads         = (rawDownloads is Map<String, dynamic>) ? rawDownloads : <String, dynamic>{};

      if (serverVersionCode == 0 || serverVersion.isEmpty) return null;

      await prefs.setInt(_prefLastCheck, DateTime.now().millisecondsSinceEpoch);

      final packageInfo   = await PackageInfo.fromPlatform();
      final installedCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('[UpdateService] Installed: $installedCode  Server: $serverVersionCode');

      if (serverVersionCode <= installedCode) return null;

      final skippedCode = prefs.getInt(_prefSkippedCode) ?? 0;
      if (skippedCode >= serverVersionCode) return null;

      final abi       = _detectAbi();
      final directUrl = abi == 'arm64'
          ? (downloads['arm64'] as String? ?? Environment.arm64DownloadUrl)
          : (downloads['arm32'] as String? ?? Environment.arm32DownloadUrl);

      return UpdateInfo(
        version:       serverVersion,
        versionCode:   serverVersionCode,
        installedCode: installedCode,
        changelog:     changelog,
        downloadUrl:   downloads['auto'] as String? ?? Environment.downloadUrl,
        directUrl:     directUrl,
        releaseDate:   data['date'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
      return null;
    }
  }

  Future<void> checkAndNotify() async {
    final info = await checkForUpdate();
    if (info != null) {
      await UpdateNotificationService.instance.showUpdateNotification(info);
    }
  }

  Future<void> remindLater(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSkippedCode, versionCode);
  }

  // registerDevice() was removed — use DeviceService.instance.registerIfNeeded()
  // which sends the full device payload (model, android_version, locale) using
  // device_info_plus. UpdateService no longer handles device registration.

  String _detectAbi() {
    try {
      final abi = Abi.current();
      if (abi == Abi.androidArm64) return 'arm64';
      if (abi == Abi.androidArm)   return 'arm32';
      if (abi == Abi.androidX64)   return 'arm64';
    } catch (_) {}
    return 'arm64';
  }
}

class UpdateInfo {
  final String version;
  final int    versionCode;
  final int    installedCode;
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
