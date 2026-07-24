// lib/core/services/device_service.dart
//
// Registers this device with the Worker on first launch and updates
// the record whenever the app version changes.
//
// Only calls the network when the build number has changed
// (stored in SharedPreferences as 'otya_registered_build').

import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/environment.dart';
import 'api_signer.dart';
import 'http_client.dart';

const _kDeviceId        = 'otya_device_id';
const _kRegisteredBuild = 'otya_registered_build';

class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  final _http       = AppHttpClient.instance;
  // Singleton — DeviceInfoPlugin is heavy; instantiate once, not per call.
  final _deviceInfo = DeviceInfoPlugin();
  String? _cachedDeviceId;

  /// Returns the stable device ID (generated once, stored in SharedPreferences).
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    String? id  = prefs.getString(_kDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceId, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  /// Registers (or updates) this device on the Worker.
  /// Only calls the network when the build number has changed.
  Future<void> registerIfNeeded() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = packageInfo.buildNumber;

      // Skip if already registered for this build
      if (prefs.getString(_kRegisteredBuild) == currentBuild) return;

      final deviceId   = await getDeviceId();
      String model          = 'unknown';
      String androidVersion = 'unknown';

      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        model          = '${android.manufacturer} ${android.model}';
        androidVersion = android.version.release;
      }

      const path = '/api/device';
      final headers = {
        ...ApiSigner.signedHeaders(
          method: 'POST',
          path: path,
          deviceId: deviceId,
        ),
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'device_id':       deviceId,
        'model':           model,
        'android_version': androidVersion,
        'app_version':     packageInfo.version,
        'app_build':       int.tryParse(currentBuild) ?? 0,
        'arch':            _detectArch(),
        'locale':          Platform.localeName,
      });

      final response = await _http.post(
        Uri.parse('${Environment.workerUrl}$path'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        await prefs.setString(_kRegisteredBuild, currentBuild);
        debugPrint('[DeviceService] registered device $deviceId');
      } else {
        debugPrint(
          '[DeviceService] registration returned ${response.statusCode}: '
          '${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[DeviceService] error (non-fatal): $e');
    }
  }

  String _detectArch() {
    // Flutter does not expose ABI directly at runtime.
    // For precision, pass the ABI via --dart-define at build time:
    //   flutter build apk --dart-define=APP_ARCH=arm64
    const arch = String.fromEnvironment('APP_ARCH', defaultValue: 'arm64');
    return arch;
  }
}
