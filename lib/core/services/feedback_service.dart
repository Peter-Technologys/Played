import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/environment.dart';

/// Handles Rate Us and Report a Problem.
/// Appwrite calls are fire-and-forget — if they fail the email still goes through.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const String _prefDeviceId      = 'update_device_id';
  static const String _prefRatePromptKey = 'rate_prompt_shown_version';

  // ── Shared helpers ────────────────────────────────────────────────────────

  Future<Map<String, String>> _deviceInfo() async {
    final pkg    = await PackageInfo.fromPlatform();
    final prefs  = await SharedPreferences.getInstance();
    final device = prefs.getString(_prefDeviceId) ?? 'unknown';
    return {
      'version':     pkg.version,
      'buildNumber': pkg.buildNumber,
      'deviceId':    device,
    };
  }

  Future<bool> _hasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  Future<void> _postToAppwrite(
      String collection, Map<String, dynamic> data) async {
    try {
      await http
          .post(
            Uri.parse(
              '${Environment.appwriteEndpoint}/databases/${Environment.databaseId}'
              '/collections/$collection/documents',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Appwrite-Project': Environment.appwriteProjectId,
            },
            body: jsonEncode({'documentId': 'unique()', 'data': data}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[FeedbackService] Appwrite post failed (non-fatal): $e');
    }
  }

  Future<void> _openEmail(String subject, String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: Environment.supportEmail,
      queryParameters: {'subject': subject, 'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('[FeedbackService] Could not open mail app.');
    }
  }

  // ── Rate Us ───────────────────────────────────────────────────────────────

  /// Returns true if the Rate Us sheet should be shown:
  ///   1. Device has an active internet connection.
  ///   2. The sheet has not already been shown for this app version.
  /// Call this on app foreground / home screen load.
  Future<bool> shouldShowRatePrompt() async {
    if (!await _hasConnection()) return false;
    final pkg    = await PackageInfo.fromPlatform();
    final prefs  = await SharedPreferences.getInstance();
    final shown  = prefs.getString(_prefRatePromptKey) ?? '';
    return shown != pkg.version;
  }

  /// Mark the Rate Us prompt as shown for the current version so it
  /// does not pop up again until the next app update.
  Future<void> markRatePromptShown() async {
    final pkg   = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRatePromptKey, pkg.version);
  }

  /// Submit a star rating + comment to Appwrite AND open a pre-filled email.
  Future<void> submitRating({
    required int stars,
    required String comment,
  }) async {
    final info = await _deviceInfo();
    final now  = DateTime.now().toUtc().toIso8601String();

    // 1. Post to Appwrite (fire-and-forget)
    _postToAppwrite('ratings', {
      'deviceId':    info['deviceId'],
      'appVersion':  info['version'],
      'versionCode': int.tryParse(info['buildNumber']!) ?? 0,
      'stars':       stars,
      'comment':     comment,
      'createdAt':   now,
    }).ignore();

    // 2. Open email
    final starEmoji = List.filled(stars, '⭐').join();
    final subject   = 'OTYA Player Rating — $stars stars';
    final body =
        'Stars: $starEmoji ($stars/5)\n'
        '${comment.isNotEmpty ? 'Comment: $comment\n' : ''}\n'
        'App version: ${info['version']} (${info['buildNumber']})\n'
        'Device ID: ${info['deviceId']}';

    await _openEmail(subject, body);
  }

  // ── Report a Problem ──────────────────────────────────────────────────────

  /// Submit a bug/problem report to Appwrite AND open a pre-filled email.
  Future<void> submitReport({
    required String description,
    required String category,
    String? userEmail,
  }) async {
    final info = await _deviceInfo();
    final now  = DateTime.now().toUtc().toIso8601String();

    // 1. Post to Appwrite (fire-and-forget)
    _postToAppwrite('feedback', {
      'deviceId':    info['deviceId'],
      'appVersion':  info['version'],
      'versionCode': int.tryParse(info['buildNumber']!) ?? 0,
      'category':    category,
      'description': description,
      'createdAt':   now,
      if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
    }).ignore();

    // 2. Open email
    final categoryLabel = category[0].toUpperCase() + category.substring(1);
    final subject = 'OTYA Player Problem Report — $categoryLabel';
    final body =
        'Category: $categoryLabel\n'
        'Description: $description\n\n'
        'App version: ${info['version']} (${info['buildNumber']})\n'
        'Device ID: ${info['deviceId']}'
        '${userEmail != null && userEmail.isNotEmpty ? '\nUser email: $userEmail' : ''}';

    await _openEmail(subject, body);
  }
}
