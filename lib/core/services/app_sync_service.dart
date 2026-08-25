// lib/core/services/app_sync_service.dart
//
// AppSyncService — called once when the app detects an internet connection.
// Sends device state to /api/sync and handles the response.
// Fire-and-forget safe: all errors are caught and logged, never thrown.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import 'api_signer.dart';
import 'device_service.dart';
import 'otya_service.dart';

/// AppSyncService — called once when the app detects an internet connection.
/// Sends device state to /api/sync and handles the response
/// (update prompts, welcome-back messages, etc.).
/// Fire-and-forget safe: all errors are caught and logged, never thrown.
class AppSyncService {
  AppSyncService._();
  static final AppSyncService instance = AppSyncService._();

  static const String _kLastSyncTime = 'otya_app_last_sync_ms';
  static const Duration _syncCooldown = Duration(hours: 1);

  bool _syncInProgress = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks the cooldown window and calls [syncOnline] if enough time has
  /// passed since the last successful sync.
  Future<void> syncOnlineIfNeeded(BuildContext? context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_kLastSyncTime) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastSyncMs;
      if (elapsed < _syncCooldown.inMilliseconds) {
        debugPrint('[AppSync] Skipping — last sync was ${elapsed ~/ 1000}s ago '
            '(cooldown: ${_syncCooldown.inSeconds}s).');
        return;
      }
      await syncOnline(context);
    } catch (e) {
      debugPrint('[AppSync] syncOnlineIfNeeded error (non-fatal): $e');
    }
  }

  /// Main entry point. Sends device state to /api/sync and handles the
  /// response (update prompts, welcome-back messages, etc.).
  ///
  /// Pass [force] = true to bypass the cooldown check.
  /// Never throws — all errors are caught and logged.
  Future<void> syncOnline(BuildContext? context, {bool force = false}) async {
    // Guard: prevent concurrent syncs.
    if (_syncInProgress) {
      debugPrint('[AppSync] Sync already in progress — skipping.');
      return;
    }

    _syncInProgress = true;
    try {
      await _doSync(context, force: force);
    } catch (e) {
      debugPrint('[AppSync] syncOnline unexpected error (non-fatal): $e');
    } finally {
      _syncInProgress = false;
    }
  }

  // ── Internal implementation ────────────────────────────────────────────────

  Future<void> _doSync(BuildContext? context, {bool force = false}) async {
    // Capture messenger before any await — context may be invalid after async gaps.
    final messenger = context != null && context.mounted
        ? ScaffoldMessenger.of(context)
        : null;

    final prefs = await SharedPreferences.getInstance();

    // Cooldown guard (also checked in syncOnlineIfNeeded, but syncOnline can
    // be called directly — so we guard here too unless force = true).
    if (!force) {
      final lastSyncMs = prefs.getInt(_kLastSyncTime) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastSyncMs;
      if (elapsed < _syncCooldown.inMilliseconds) {
        debugPrint('[AppSync] Skipping — within cooldown window.');
        return;
      }
    }

    debugPrint('[AppSync] Starting sync…');

    // ── Gather device state ──────────────────────────────────────────────────

    final deviceId = await DeviceService.instance.getDeviceId();
    debugPrint('[AppSync] device_id: $deviceId');

    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    final versionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    debugPrint('[AppSync] app_version: $appVersion  version_code: $versionCode');

    // FCM token — stored by FcmService under the key 'fcm_token'.
    final fcmToken = prefs.getString('fcm_token');
    debugPrint('[AppSync] fcm_token: ${fcmToken != null ? '(present)' : '(absent)'}');

    // ABI — injected at build time via --dart-define=APP_ARCH=arm64.
    const abi = Environment.appArch;
    debugPrint('[AppSync] abi: $abi');

    // ── Build request body ───────────────────────────────────────────────────

    final body = <String, dynamic>{
      'device_id':    deviceId,
      'version_code': versionCode,
      'app_version':  appVersion,
      'abi':          abi,
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
    };

    // ── Sign and POST ────────────────────────────────────────────────────────

    const path = '/api/sync';
    final headers = {
      ...ApiSigner.signedHeaders(
        method: 'POST',
        path: path,
        deviceId: deviceId,
      ),
      'Content-Type': 'application/json',
    };

    debugPrint('[AppSync] POSTing to ${Environment.workerUrl}$path…');

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${Environment.workerUrl}$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[AppSync] Network error (non-fatal): $e');
      return;
    }

    debugPrint('[AppSync] Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[AppSync] Unexpected status ${response.statusCode} — aborting.');
      return;
    }

    // ── Parse response ───────────────────────────────────────────────────────

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AppSync] Response JSON parse error: $e');
      return;
    }

    final upToDate       = (data['upToDate']       as bool?)   ?? true;
    final latestVersion  = (data['latestVersion']  as String?) ?? '';
    final message        = (data['message']        as String?) ?? '';
    final welcomeBack    = (data['welcomeBack']    as bool?)   ?? false;

    debugPrint('[AppSync] upToDate=$upToDate  latestVersion=$latestVersion  '
        'welcomeBack=$welcomeBack  message=$message');

    // ── Handle response actions ──────────────────────────────────────────────

    if (!upToDate && messenger != null) {
      debugPrint('[AppSync] Update available — showing snackbar.');
      final label = latestVersion.isNotEmpty
          ? 'Update available: v$latestVersion'
          : 'Update available';
      messenger.showSnackBar(
        SnackBar(
          content: Text(label),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () =>
                OtyaService.instance.checkAppUpdate(context!, force: true),
          ),
        ),
      );
    }

    if (welcomeBack == true && messenger != null) {
      debugPrint('[AppSync] Welcome back — showing snackbar.');
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Welcome back! Here's what's new."),
          duration: Duration(seconds: 4),
        ),
      );
    }

    // ── Persist sync timestamp ───────────────────────────────────────────────

    await prefs.setInt(_kLastSyncTime, DateTime.now().millisecondsSinceEpoch);
    debugPrint('[AppSync] Sync complete — timestamp saved.');
  }
}
