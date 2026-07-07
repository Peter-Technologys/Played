import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/environment.dart';

/// Handles Rate Us and Report a Problem.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const String _prefDeviceId = 'update_device_id';

  /// Opens WhatsApp with a pre-filled problem report.
  Future<void> reportProblem({String? description}) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final prefs       = await SharedPreferences.getInstance();
    final deviceId    = prefs.getString(_prefDeviceId) ?? 'unknown';

    final body = Uri.encodeComponent(
      'Hi! I want to report a problem with OTYA Player.\n\n'
      'App version: ${packageInfo.version} (${packageInfo.buildNumber})\n'
      'Device ID: $deviceId\n'
      '${description != null ? '\nDescription:\n$description' : ''}\n\n'
      'Please describe what happened:',
    );

    final whatsapp = Uri.parse('https://wa.me/256775912582?text=$body');
    if (await canLaunchUrl(whatsapp)) {
      await launchUrl(whatsapp, mode: LaunchMode.externalApplication);
      return;
    }
    // Fallback to email
    final email = Uri.parse(
      'mailto:${Environment.supportEmail}'
      '?subject=OTYA+Player+Problem+Report'
      '&body=${Uri.encodeComponent(
        'App version: ${packageInfo.version}\nDevice ID: $deviceId\n\n'
        '${description ?? 'Please describe the problem here.'}',
      )}',
    );
    if (await canLaunchUrl(email)) {
      await launchUrl(email, mode: LaunchMode.externalApplication);
    }
  }

  /// Submits report to Appwrite + opens WhatsApp.
  Future<void> submitReport({
    required String description,
    String category = 'bug',
  }) async {
    // Open WhatsApp immediately so user isn't waiting
    reportProblem(description: description).ignore();

    // Log to Appwrite silently
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final prefs       = await SharedPreferences.getInstance();
      final deviceId    = prefs.getString(_prefDeviceId) ?? 'unknown';

      await http.post(
        Uri.parse(
          '${Environment.appwriteEndpoint}/databases/${Environment.databaseId}'
          '/collections/feedback/documents',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-Appwrite-Project': Environment.appwriteProjectId,
        },
        body: jsonEncode({
          'documentId': 'unique()',
          'data': {
            'deviceId':    deviceId,
            'appVersion':  packageInfo.version,
            'versionCode': int.tryParse(packageInfo.buildNumber) ?? 0,
            'category':    category,
            'description': description,
            'createdAt':   DateTime.now().toUtc().toIso8601String(),
          },
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[FeedbackService] Appwrite log failed (non-fatal): $e');
    }
  }

  /// Opens Play Store rating page, falls back to website.
  Future<void> rateApp() async {
    final playStore   = Uri.parse('market://details?id=${Environment.appPackageId}');
    final playWeb     = Uri.parse('https://play.google.com/store/apps/details?id=${Environment.appPackageId}');
    final downloadPage = Uri.parse(Environment.downloadPageUrl);

    if (await canLaunchUrl(playStore)) {
      await launchUrl(playStore, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(playWeb)) {
      await launchUrl(playWeb, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(downloadPage, mode: LaunchMode.externalApplication);
    }
  }
}
