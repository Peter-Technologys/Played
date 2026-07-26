import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apk_downloader.dart';
import 'otya_service.dart';
import 'push_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level background message handler
//
// Must be a top-level function annotated with @pragma('vm:entry-point') so
// the Dart VM can locate it from the native FCM background isolate.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Note: Firebase is already initialised by the native layer before this
  // function is called, so we do NOT call Firebase.initializeApp() here.
  debugPrint('[FCM] Background message: ${message.messageId}');

  final data = message.data;
  final type = data['type'] as String?;

  await PushNotificationService.instance.init();

  if (type == 'update') {
    final version      = data['version']      as String? ?? '';
    final releaseNotes = data['release_notes'] as String? ?? 'Bug fixes and improvements.';
    final downloadUrl  = data['download_url']  as String? ?? '';
    if (downloadUrl.isNotEmpty) {
      await PushNotificationService.instance.showUpdateNotification(
        version:      version,
        releaseNotes: releaseNotes,
        downloadUrl:  downloadUrl,
      );
    }
  } else if (type == 'announcement') {
    final title = data['title'] as String? ?? 'OTYA Player';
    final body  = data['body']  as String? ?? '';
    final url   = data['url']   as String?;
    if (body.isNotEmpty) {
      await PushNotificationService.instance.showAnnouncement(
        title: title,
        body:  body,
        url:   url,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FcmService
//
// Responsibilities:
//   1. Request notification permission on Android 13+ (API 33+).
//   2. Retrieve the FCM token and persist it to SharedPreferences as
//      'fcm_token'.
//   3. Register the token with the backend via OtyaService.
//   4. Listen to foreground messages (FirebaseMessaging.onMessage) and
//      dispatch them to the appropriate UI handler.
//   5. Register the top-level background handler.
// ─────────────────────────────────────────────────────────────────────────────
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _keyFcmToken = 'fcm_token';

  bool _initialized = false;

  // Optional navigator key — set by the app so foreground handlers can show
  // SnackBars without a BuildContext.
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init() async {
    if (_initialized) return;

    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }

    try {
      // 1. Request permission (Android 13+ / iOS).
      await _requestPermission();

      // 2. Register background handler BEFORE subscribing to foreground.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Get + persist token.
      await _refreshToken();

      // 4. Listen for token refreshes.
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

      // 5. Foreground message handler.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Only mark initialized after everything succeeds so init() can be
      // retried if a transient error occurs during setup.
      _initialized = true;
      debugPrint('[FcmService] Initialized.');
    } catch (e) {
      debugPrint('[FcmService] init error (non-fatal): $e');
      // Don't set _initialized = true on failure so init() can be retried.
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert:         true,
        badge:         true,
        sound:         true,
        announcement:  false,
        carPlay:       false,
        criticalAlert: false,
        provisional:   false,
      );
      debugPrint(
        '[FcmService] Notification permission: ${settings.authorizationStatus}',
      );
    } catch (e) {
      debugPrint('[FcmService] requestPermission error: $e');
    }
  }

  // ── Token management ──────────────────────────────────────────────────────

  Future<void> _refreshToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FcmService] FCM token is null/empty — skipping registration.');
        return;
      }
      await _persistAndRegister(token);
    } catch (e) {
      debugPrint('[FcmService] getToken error: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    debugPrint('[FcmService] Token refreshed.');
    await _persistAndRegister(token);
  }

  Future<void> _persistAndRegister(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFcmToken, token);
      debugPrint('[FcmService] FCM token saved to SharedPreferences.');

      // Register with the backend — reuse the device ID already stored by
      // UpdateService so we don't create a second device identity.
      final deviceId = prefs.getString('update_device_id');
      if (deviceId != null && deviceId.isNotEmpty) {
        await OtyaService.instance.registerDevicePushToken(
          deviceId: deviceId,
          fcmToken: token,
        );
      }
    } catch (e) {
      debugPrint('[FcmService] _persistAndRegister error: $e');
    }
  }

  // ── Foreground message handler ────────────────────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('[FcmService] Foreground message: ${message.messageId}');
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'update') {
      final version     = data['version']      as String? ?? '';
      final downloadUrl = data['download_url']  as String? ?? '';
      if (downloadUrl.isNotEmpty) {
        _showUpdateSnackBar(version: version, downloadUrl: downloadUrl);
      }
    } else if (type == 'announcement') {
      final title = data['title'] as String? ?? 'OTYA Player';
      final body  = data['body']  as String? ?? '';
      final url   = data['url']   as String?;
      if (body.isNotEmpty) {
        await PushNotificationService.instance.showAnnouncement(
          title: title,
          body:  body,
          url:   url,
        );
      }
    }
  }

  // ── In-app update banner ──────────────────────────────────────────────────

  void _showUpdateSnackBar({
    required String version,
    required String downloadUrl,
  }) {
    final context = navigatorKey?.currentContext;
    if (context == null) {
      // No context available — fall back to a local notification.
      PushNotificationService.instance.showUpdateNotification(
        version:      version,
        releaseNotes: 'A new version of OTYA Player is available.',
        downloadUrl:  downloadUrl,
      ).ignore();
      return;
    }

    final label = version.isNotEmpty
        ? 'New update available — v$version'
        : 'New update available';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Download',
          onPressed: () => _startDownload(
            downloadUrl: downloadUrl,
            version:     version,
            context:     context,
          ),
        ),
      ),
    );
  }

  void _startDownload({
    required String downloadUrl,
    required String version,
    required BuildContext context,
  }) {
    PushNotificationService.instance.showDownloadProgress(percent: 0).ignore();
    ApkDownloader.instance.downloadAndInstall(
      url:     downloadUrl,
      version: version.isNotEmpty ? version : 'latest',
      onProgress: (p) => PushNotificationService.instance
          .showDownloadProgress(percent: (p * 100).round()),
      onError: (err) {
        PushNotificationService.instance.dismissDownload().ignore();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $err')),
          );
        }
      },
    ).then((_) {
      PushNotificationService.instance.showDownloadComplete().ignore();
    }).ignore();
  }
}
