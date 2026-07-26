import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apk_downloader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PushNotificationService
//
// Manages the four FCM-related Android notification channels:
//
//   otya_updates           — New version available (High importance, sound)
//   otya_download_progress — Download progress bar (Low, silent, ongoing)
//   otya_download_done     — Download complete (High, tap to install)
//   otya_announcements     — General announcements (Default importance)
//
// Notification IDs:
//   2000 — Update available
//   2001 — Download progress
//   2002 — Download complete
//   2003 — Announcement
// ─────────────────────────────────────────────────────────────────────────────
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // ── Channel IDs ───────────────────────────────────────────────────────────
  static const _chUpdates   = 'otya_updates';
  static const _chProgress  = 'otya_download_progress';
  static const _chDone      = 'otya_download_done';
  static const _chAnnounce  = 'otya_announcements';

  // ── Notification IDs ──────────────────────────────────────────────────────
  static const int idUpdate    = 2000;
  static const int idProgress  = 2001;
  static const int idDone      = 2002;
  static const int idAnnounce  = 2003;

  // ── Payload prefixes (used to route tap actions) ──────────────────────────
  static const _prefixDownload = 'download:';
  static const _prefixUrl      = 'url:';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Cached download metadata so the tap handler can trigger the installer.
  String? _pendingDownloadUrl;
  String? _pendingDownloadVersion;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onTap,
    );
    _initialized = true;
    debugPrint('[PushNotificationService] Initialized.');
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  /// Public entry-point called by [sharedNotificationRouter].
  void handleTap(NotificationResponse response) => _onTap(response);

  void _onTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    debugPrint('[PushNotif] tapped id=${response.id} payload=$payload');

    if (payload.startsWith(_prefixDownload)) {
      // Tap on update or download-complete notification → start/resume install.
      final parts = payload.substring(_prefixDownload.length).split('|');
      final url     = parts.isNotEmpty ? parts[0] : null;
      final version = parts.length > 1 ? parts[1] : 'latest';
      if (url != null && url.isNotEmpty) {
        _triggerDownload(url: url, version: version);
      }
    } else if (payload.startsWith(_prefixUrl)) {
      final rawUrl = payload.substring(_prefixUrl.length);
      final uri = Uri.tryParse(rawUrl);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication).ignore();
      }
    }
  }

  void _triggerDownload({required String url, required String version}) {
    ApkDownloader.instance.downloadAndInstall(
      url: url,
      version: version,
      onProgress: (p) =>
          showDownloadProgress(percent: (p * 100).round()),
      onError: (err) {
        debugPrint('[PushNotif] Download error: $err');
        dismissDownload();
      },
    ).then((_) => showDownloadComplete()).ignore();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Shows a high-importance "New update available" notification.
  /// Tapping it starts the APK download via [ApkDownloader].
  Future<void> showUpdateNotification({
    required String version,
    required String releaseNotes,
    required String downloadUrl,
  }) async {
    if (!_initialized) await init();
    _pendingDownloadUrl     = downloadUrl;
    _pendingDownloadVersion = version;

    final androidDetails = AndroidNotificationDetails(
      _chUpdates,
      'OTYA Player \u2014 Updates',
      channelDescription: 'Alerts when a new version of OTYA Player is available',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      styleInformation: BigTextStyleInformation(
        releaseNotes,
        contentTitle: 'OTYA Player $version is available',
        summaryText: 'Tap to download',
      ),
    );

    await _plugin.show(
      idUpdate,
      'Update Available — v$version',
      releaseNotes,
      NotificationDetails(android: androidDetails),
      payload: '$_prefixDownload$downloadUrl|$version',
    );
    debugPrint('[PushNotif] showUpdateNotification v$version');
  }

  /// Shows or updates a silent ongoing progress notification.
  Future<void> showDownloadProgress({required int percent}) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _chProgress,
      'OTYA Player \u2014 Downloading',
      channelDescription: 'Shows APK download progress',
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

    await _plugin.show(
      idProgress,
      'Downloading OTYA Player…',
      '$percent%',
      NotificationDetails(android: androidDetails),
    );
  }

  /// Dismisses the progress notification and shows a "Download complete" one.
  Future<void> showDownloadComplete() async {
    if (!_initialized) await init();
    await dismissDownload();

    final url     = _pendingDownloadUrl     ?? '';
    final version = _pendingDownloadVersion ?? 'latest';

    final androidDetails = AndroidNotificationDetails(
      _chDone,
      'OTYA Player \u2014 Download Complete',
      channelDescription: 'Notifies when the APK download is ready to install',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    await _plugin.show(
      idDone,
      'Download Complete',
      'Tap to install OTYA Player $version',
      NotificationDetails(android: androidDetails),
      payload: '$_prefixDownload$url|$version',
    );
    debugPrint('[PushNotif] showDownloadComplete');
  }

  /// Shows a general announcement notification.
  /// If [url] is provided, tapping opens it in the browser.
  Future<void> showAnnouncement({
    required String title,
    required String body,
    String? url,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _chAnnounce,
      'OTYA Player \u2014 Announcements',
      channelDescription: 'General announcements from the OTYA Player team',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@drawable/ic_notification',
      styleInformation: BigTextStyleInformation(body),
    );

    await _plugin.show(
      idAnnounce,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: url != null && url.isNotEmpty ? '$_prefixUrl$url' : null,
    );
    debugPrint('[PushNotif] showAnnouncement: $title');
  }

  /// Cancels the ongoing download-progress notification.
  Future<void> dismissDownload() async {
    if (!_initialized) return;
    await _plugin.cancel(idProgress);
  }
}
