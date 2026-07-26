// lib/core/services/pro_churn_service.dart
//
// ProChurnService — checks the user's Pro subscription expiry on app start
// and shows a local notification if expiry is imminent or has already passed.
//
// Reads 'pro_expiry_ms' from SharedPreferences (written by ProService).
// Shows notifications via PushNotificationService (existing channel).
//
// Usage:
//   await ProChurnService.instance.checkAndNotify();

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_notification_plugin.dart';

/// Notification IDs used by this service (outside the ranges of other services).
const int _kChurnNotificationId = 3000;

/// Singleton that checks Pro expiry and shows a churn-prevention notification.
class ProChurnService {
  ProChurnService._();
  static final ProChurnService instance = ProChurnService._();

  static const String _kProExpiry = 'pro_expiry_ms';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Check the stored Pro expiry and show a local notification if needed.
  ///
  /// Call this once on app start, after SharedPreferences is available.
  /// Never throws — all errors are caught and logged.
  Future<void> checkAndNotify() async {
    try {
      await _doCheckAndNotify();
    } catch (e) {
      debugPrint('[ProChurn] checkAndNotify error (non-fatal): $e');
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _doCheckAndNotify() async {
    final prefs    = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_kProExpiry) ?? 0;

    if (expiryMs <= 0) {
      // No Pro record — user was never Pro or already cleaned up.
      debugPrint('[ProChurn] No pro_expiry_ms found — skipping.');
      return;
    }

    final now       = DateTime.now().millisecondsSinceEpoch;
    final diffMs    = expiryMs - now;
    final diffDays  = diffMs / 86400000.0;

    String? title;
    String? body;

    if (diffMs <= 0) {
      // Already expired.
      title = 'Your Pro access has ended';
      body  = 'Your Pro access has ended — upgrade to keep premium features.';
      debugPrint('[ProChurn] Pro expired — showing expired notification.');
    } else if (diffDays <= 3.0) {
      // Expiring within 3 days.
      final daysLeft = diffDays.ceil();
      final dayWord  = daysLeft == 1 ? 'day' : 'days';
      title = 'Pro subscription expiring soon ⚠️';
      body  = 'Your Pro subscription expires in $daysLeft $dayWord — renew now!';
      debugPrint('[ProChurn] Pro expiring in $daysLeft $dayWord — showing warning.');
    } else {
      // More than 3 days left — no notification needed.
      debugPrint('[ProChurn] Pro active for ${diffDays.toStringAsFixed(1)} more days — no notification.');
      return;
    }

    await _showNotification(title: title, body: body);
  }

  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    await initSharedNotificationsPlugin();

    const androidDetails = AndroidNotificationDetails(
      'otya_pro_churn',
      'OTYA Player — Pro Subscription',
      channelDescription: 'Alerts about your Pro subscription status',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );

    await sharedNotificationsPlugin.show(
      _kChurnNotificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'https://petersmartlink.com',
    );

    debugPrint('[ProChurn] Notification shown: $title');
  }
}
