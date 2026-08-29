import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../config/environment.dart';
import 'auth_service.dart';
import 'device_service.dart';
import 'push_notification_service.dart';

/// Build-time Firebase client configuration.
///
/// Firebase is used ONLY as the Android push transport. OTYA identity, data,
/// support and notification business logic remain on the Cloudflare backend.
/// Missing Firebase values disable remote push without blocking local media
/// playback or app startup.
abstract final class OtyaFirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get configured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
      );
}

@pragma('vm:entry-point')
Future<void> otyaFirebaseBackgroundHandler(RemoteMessage message) async {
  if (!OtyaFirebaseConfig.configured) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: OtyaFirebaseConfig.options);
    }
  } catch (e) {
    debugPrint('[FCM:bg] Firebase init skipped: $e');
  }
  // Android can display a notification payload while OTYA is backgrounded.
  // OTYA processes navigation only after the user opens the app.
  debugPrint('[FCM:bg] message=${message.messageId}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _keyFcmToken = 'fcm_token';
  bool _initialized = false;

  /// Public destinations that a backend notification is allowed to open.
  /// This is intentionally an allow-list: a remote push must not be able to
  /// navigate to arbitrary internal/admin/debug screens.
  static const Set<String> _allowedRoutes = {
    '/',
    '/music',
    '/myspace',
    '/support',
    '/transfer',
    '/downloads',
    '/settings',
    '/settings/storage',
    '/profile',
    '/about',
    '/privacy',
    '/whats-new',
    '/playlists',
    '/history',
  };

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isAndroid) {
      debugPrint('[FCM] Android transport not required on this platform.');
      return;
    }
    if (!OtyaFirebaseConfig.configured) {
      debugPrint('[FCM] Disabled: Firebase build configuration is incomplete.');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: OtyaFirebaseConfig.options);
      }
      FirebaseMessaging.onBackgroundMessage(otyaFirebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      messaging.onTokenRefresh.listen((token) {
        _storeAndRegister(token).ignore();
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleOpenedMessage(initialMessage);
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _storeAndRegister(token);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_keyFcmToken);
        if (cached != null && cached.isNotEmpty) {
          await _registerWithBackend(cached);
        }
      }

      debugPrint('[FCM] Initialized and token sync requested.');
    } catch (e, st) {
      debugPrint('[FCM] init error (non-fatal): $e\n$st');
    }
  }

  Future<void> syncRegistration() async {
    if (!OtyaFirebaseConfig.configured || !Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyFcmToken) ??
          await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _storeAndRegister(token);
      }
    } catch (e) {
      debugPrint('[FCM] registration sync failed (non-fatal): $e');
    }
  }

  Future<void> _storeAndRegister(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFcmToken, token);
    await _registerWithBackend(token);
  }

  Future<void> _registerWithBackend(String token) async {
    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final packageInfo = await PackageInfo.fromPlatform();
      final accessToken = await AuthService.instance.getValidToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http
          .post(
            Uri.parse(Environment.apiDeviceUrl),
            headers: headers,
            body: jsonEncode({
              'device_id': deviceId,
              'app_version': packageInfo.version,
              'app_build': int.tryParse(packageInfo.buildNumber) ?? 0,
              'arch': Environment.appArch,
              'platform': 'android',
              'locale': Platform.localeName,
              'fcm_token': token,
            }),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('[FCM] device token registration → ${response.statusCode}');
    } catch (e) {
      debugPrint('[FCM] backend registration failed (non-fatal): $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null || title.isEmpty || body == null || body.isEmpty) return;

    final type = message.data['type']?.toString();
    if (type == 'update') {
      final version = message.data['version']?.toString();
      final downloadUrl = message.data['download_url']?.toString() ??
          message.data['url']?.toString();
      if (version != null &&
          version.isNotEmpty &&
          downloadUrl != null &&
          downloadUrl.isNotEmpty) {
        await PushNotificationService.instance.showUpdateNotification(
          version: version,
          releaseNotes: body,
          downloadUrl: downloadUrl,
        );
        return;
      }
    }

    await PushNotificationService.instance.showAnnouncement(
      title: title,
      body: body,
      url: _notificationTarget(message),
    );
  }

  String? _notificationTarget(RemoteMessage message) {
    final route = _canonicalRoute(message.data['route']?.toString());
    if (route != null) return 'otya://app$route';
    return message.data['url']?.toString();
  }

  String? _canonicalRoute(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var route = raw.trim();

    // Preserve old notification payloads after the product rename/migration.
    if (route == '/ai') route = '/support';
    if (route == '/airdrop') route = '/transfer';
    if (route == '/home') route = '/';

    return _allowedRoutes.contains(route) ? route : null;
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final route = _canonicalRoute(message.data['route']?.toString());
    if (route != null) {
      try {
        AppRouter.router.go(route);
        return;
      } catch (e) {
        debugPrint('[FCM] in-app notification route failed: $e');
      }
    }

    final rawUrl = message.data['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) return;

    // Compatibility for local-notification payloads that contain an OTYA URI.
    final appUri = Uri.tryParse(rawUrl);
    if (appUri != null && appUri.scheme == 'otya' && appUri.host == 'app') {
      final appRoute = _canonicalRoute(appUri.path);
      if (appRoute != null) {
        try {
          AppRouter.router.go(appRoute);
        } catch (e) {
          debugPrint('[FCM] OTYA URI route failed: $e');
        }
      }
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !{'https', 'http'}.contains(uri.scheme)) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[FCM] notification URL open failed: $e');
    }
  }
}
