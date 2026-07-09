import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/environment.dart';
import '../config/flavor_config.dart';
import 'update_notification_service.dart';

/// Checks if a newer version of OTYA Player is available.
///
/// Compares server versionCode (integer) against BuildConfig.VERSION_CODE
/// via package_info_plus — no hardcoded version strings.
///
/// WorkManager scheduling is handled by UpdateCheckWorker (Kotlin side).
/// This service is called both from WorkManager and on app foreground.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _prefLastCheck   = 'update_last_check';
  static const String _prefSkippedCode = 'update_skipped_code';
  static const String _prefDeviceId    = 'update_device_id';

  // Guard against concurrent SharedPreferences access
  bool _checkInProgress      = false;
  bool _registerInProgress   = false;

  String get downloadUrl => Environment.downloadUrl;

  /// Returns [UpdateInfo] if a newer version is available, null otherwise.
  /// Checks at most once per 24 hours unless [force] is true.
  /// Guards against concurrent calls.
  ///
  /// Returns null immediately when [FlavorConfig.selfUpdateEnabled] is false
  /// (i.e. the Google Play / standard flavor) — updates are handled by the
  /// Play Store in that case.
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

      // Throttle: only check once per day unless forced
      if (!force) {
        final lastCheck = prefs.getInt(_prefLastCheck) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastCheck < const Duration(hours: 24).inMilliseconds) {
          debugPrint('[UpdateService] Skipping check — checked within 24h.');
          return null;
        }
      }

      // Use /latest — returns structured JSON with downloads object
      final response = await http
          .get(Uri.parse(Environment.latestUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] HTTP ${response.statusCode} from version endpoint.');
        return null;
      }

      final data              = jsonDecode(response.body) as Map<String, dynamic>;
      final serverVersionCode = (data['versionCode'] as num?)?.toInt() ?? 0;
      final serverVersion     = data['version']   as String? ?? '';
      final changelog         = data['changelog'] as String? ?? '';
      final rawDownloads      = data['downloads'];
      final downloads         = (rawDownloads is Map<String, dynamic>) ? rawDownloads : <String, dynamic>{};

      if (serverVersionCode == 0 || serverVersion.isEmpty) return null;

      // Save the time we last checked
      await prefs.setInt(_prefLastCheck, DateTime.now().millisecondsSinceEpoch);

      // Get installed versionCode from the OS (not a hardcoded string)
      final packageInfo = await PackageInfo.fromPlatform();
      final installedCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('[UpdateService] Installed: $installedCode  Server: $serverVersionCode');

      if (serverVersionCode <= installedCode) return null;

      // Check if user already dismissed this exact version
      final skippedCode = prefs.getInt(_prefSkippedCode) ?? 0;
      if (skippedCode >= serverVersionCode) return null;

      // Use ABI-specific URL from Worker response
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

  /// Called by WorkManager worker — checks and shows notification if update found.
  Future<void> checkAndNotify() async {
    final info = await checkForUpdate();
    if (info != null) {
      await UpdateNotificationService.instance.showUpdateNotification(info);
    }
  }

  /// User tapped "Later" — skip this version code until next app open.
  Future<void> remindLater(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSkippedCode, versionCode);
  }

  /// Register this device on first launch. Guards against concurrent calls.
  Future<void> registerDevice() async {
    if (_registerInProgress) return;
    _registerInProgress = true;
    try {
      await _doRegisterDevice();
    } finally {
      _registerInProgress = false;
    }
  }

  Future<void> _doRegisterDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_prefDeviceId);
      if (deviceId == null) {
        deviceId = _generateDeviceId();
        await prefs.setString(_prefDeviceId, deviceId);
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final installedCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final abi = _detectAbi();
      final now = DateTime.now().toUtc().toIso8601String();

      // POST to Appwrite REST — no SDK needed, avoids auth requirement
      final url = '${Environment.appwriteEndpoint}/databases/${Environment.databaseId}'
          '/collections/${Environment.devicesCollection}/documents';

      final body = jsonEncode({
        'documentId': deviceId,
        'data': {
          'deviceId':      deviceId,
          'appVersion':    packageInfo.version,
          'versionCode':   installedCode,
          'abi':           abi,
          'platform':      'android',
          'registeredAt':  now,
          'lastSeenAt':    now,
        },
      });

      // Try update first, then create
      final updateRes = await http.patch(
        Uri.parse('$url/$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'X-Appwrite-Project': Environment.appwriteProjectId,
        },
        body: jsonEncode({'data': {
          'appVersion':  packageInfo.version,
          'versionCode': installedCode,
          'lastSeenAt':  now,
        }}),
      ).timeout(const Duration(seconds: 8));

      if (updateRes.statusCode == 404) {
        // Device not registered yet — create it
        await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-Appwrite-Project': Environment.appwriteProjectId,
          },
          body: body,
        ).timeout(const Duration(seconds: 8));
      }

      debugPrint('[UpdateService] Device registered: $deviceId');
    } catch (e) {
      debugPrint('[UpdateService] registerDevice failed (non-fatal): $e');
    }
  }

  String _detectAbi() {
    try {
      if (Platform.isAndroid) {
        // Primary: check SUPPORTED_ABIS environment variable (set by Android runtime)
        final abis = Platform.environment['SUPPORTED_ABIS'] ?? '';
        if (abis.contains('arm64-v8a')) return 'arm64';
        if (abis.contains('armeabi-v7a')) return 'arm32';
        // Fallback: read /proc/cpuinfo
        final cpuinfo = File('/proc/cpuinfo').readAsStringSync();
        if (cpuinfo.contains('aarch64') || cpuinfo.contains('arm64')) return 'arm64';
        if (cpuinfo.contains('armv7')   || cpuinfo.contains('armeabi')) return 'arm32';
      }
    } catch (_) {}
    return 'arm64'; // safe default — covers 99%+ of modern devices
  }

  String _generateDeviceId() {
    // Use UUID v4 for a cryptographically random, globally unique device ID.
    // The uuid package is already declared in pubspec.yaml.
    return const Uuid().v4();
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
