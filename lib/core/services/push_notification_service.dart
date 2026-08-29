import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import 'apk_downloader.dart';
import 'shared_notification_plugin.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PushNotificationService
//
// Manages the four FCM-related Android notification channels:
//
//   otya_updates           — New version available (High importance, sound)
//   otya_download_progress — Download progress bar (Low, silent, ongoing)
//   otya_download_done     — Download complete (High, tap to install)
//   otya_announcements     — General announcements (Default importance)
// ─────────────────────────────────────────────────────────────────────────────
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _chUpdates = 'otya_updates';
  static const _chProgress = 'otya_download_progress';
  static const _chDone = 'otya_download_done';
  static const _chAnnounce = 'otya_announcements';

  static const int idUpdate = 2000;
  static const int idProgress = 2001;
  static const int idDone = 2002;
  static const int idAnnounce = 2003;

  static const _prefixDownload = 'download:';
  static const _prefixUrl = 'url:';

  bool _initialized = false;
  String? _pendingDownloadUrl;
  String? _pendingDownloadVersion;

  Future<void> init() async {
    if (_initialized) return;
    await initSharedNotificationsPlugin();
    _initialized = true;
    debugPrint('[PushNotificationService] Initialized.');
  }

  /// Public entry-point called by [sharedNotificationRouter].
  void handleTap(NotificationResponse response) => _onTap(response);

  void _onTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    debugPrint('[PushNotif] tapped id=${response.id} payload=$payload');

    if (payload.startsWith(_prefixDownload)) {
      final parts = payload.substring(_prefixDownload.length).split('|');
      final url = parts.isNotEmpty ? parts[0] : null;
      final version = parts.length > 1 ? parts[1] : 'latest';
      if (url != null && url.isNotEmpty) {
        _triggerDownload(url: url, version: version);
      }
      return;
    }

    if (!payload.startsWith(_prefixUrl)) return;
    final rawUrl = payload.substring(_prefixUrl.length);
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    if (uri.scheme == 'otya' && uri.host == 'app') {
      final route = _canonicalRoute(uri.path);
      if (route != null) {
        try {
          AppRouter.router.go(route);
        } catch (e) {
          debugPrint('[PushNotif] app route failed: $e');
        }
      }
      return;
    }

    if ({'http', 'https'}.contains(uri.scheme)) {
      launchUrl(uri, mode: LaunchMode.externalApplication).ignore();
    }
  }

  String? _canonicalRoute(String raw) {
    var route = raw.trim();
    if (route == '/ai') route = '/support';
    if (route == '/airdrop') route = '/transfer';
    if (route == '/home') route = '/';

    const allowed = {
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
    return allowed.contains(route) ? route : null;
  }

  void _triggerDownload({required String url, required String version}) {
    ApkDownloader.instance
        .downloadAndInstall(
          url: url,
          version: version,
          onProgress: (p) => showDownloadProgress(percent: (p * 100).round()),
          onError: (err) {
            debugPrint('[PushNotif] Download error: $err');
            dismissDownload();
          },
        )
        .then((_) => showDownloadComplete())
        .ignore();
  }

  Future<void> showUpdateNotification({
    required String version,
    required String releaseNotes,
    required String downloadUrl,
  }) async {
    if (!_initialized) await init();
    _pendingDownloadUrl = downloadUrl;
    _pendingDownloadVersion = version;

    final androidDetails = AndroidNotificationDetails(
      _chUpdates,
      'OTYA — Updates',
      channelDescription: 'Alerts when a new OTYA version is available',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      styleInformation: BigTextStyleInformation(
        releaseNotes,
        contentTitle: 'OTYA $version is available',
        summaryText: 'Tap to download',
      ),
    );

    await sharedNotificationsPlugin.show(
      idUpdate,
      'Update available — v$version',
      releaseNotes,
      NotificationDetails(android: androidDetails),
      payload: '$_prefixDownload$downloadUrl|$version',
    );
    debugPrint('[PushNotif] showUpdateNotification v$version');
  }

  Future<void> showDownloadProgress({required int percent}) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _chProgress,
      'OTYA — Downloading',
      channelDescription: 'Shows OTYA update download progress',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: percent,
      icon: '@drawable/ic_notification',
    );

    await sharedNotificationsPlugin.show(
      idProgress,
      'Downloading OTYA…',
      '$percent%',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showDownloadComplete() async {
    if (!_initialized) await init();
    await dismissDownload();

    final url = _pendingDownloadUrl ?? '';
    final version = _pendingDownloadVersion ?? 'latest';

    final androidDetails = AndroidNotificationDetails(
      _chDone,
      'OTYA — Download complete',
      channelDescription: 'Notifies when an OTYA update is ready to install',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    await sharedNotificationsPlugin.show(
      idDone,
      'Download complete',
      'Tap to install OTYA $version',
      NotificationDetails(android: androidDetails),
      payload: '$_prefixDownload$url|$version',
    );
    debugPrint('[PushNotif] showDownloadComplete');
  }

  /// Shows a general announcement notification.
  /// [url] may be an http(s) URL or a safe `otya://app/<route>` target.
  Future<void> showAnnouncement({
    required String title,
    required String body,
    String? url,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _chAnnounce,
      'OTYA — Announcements',
      channelDescription: 'General announcements from OTYA',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/ic_notification',
      styleInformation: BigTextStyleInformation(body),
    );

    await sharedNotificationsPlugin.show(
      idAnnounce,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: url != null && url.isNotEmpty ? '$_prefixUrl$url' : null,
    );
    debugPrint('[PushNotif] showAnnouncement: $title');
  }

  Future<void> dismissDownload() async {
    if (!_initialized) return;
    await sharedNotificationsPlugin.cancel(idProgress);
  }
}
