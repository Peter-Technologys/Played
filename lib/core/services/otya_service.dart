import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../config/environment.dart';
import 'api_signer.dart';
import 'apk_downloader.dart';
import 'push_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────────
class OtyaService {
  OtyaService._();
  static final OtyaService instance = OtyaService._();

  static const String _keyLastUpdate = 'otya_update_last_check';
  static String get _checkUpdateUrl  => '${Environment.workerUrl}/check-update';

  bool _updateCheckInProgress = false;

  // ─────────────────────────────────────────────────────────────────────────────────
  // checkAppUpdate
  //
  // Compares the installed build number against the Worker’s versionCode.
  // Shows a branded AlertDialog if an update is available.
  // Throttled to once per 24 h unless [force] is true.
  // ─────────────────────────────────────────────────────────────────────────────────
  Future<void> checkAppUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_updateCheckInProgress) return;
    _updateCheckInProgress = true;
    try {
      await _doCheckAppUpdate(context, force: force);
    } catch (e) {
      debugPrint('[OtyaService] checkAppUpdate unexpected error: $e');
    } finally {
      _updateCheckInProgress = false;
    }
  }

  Future<void> _doCheckAppUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!force) {
      final lastCheck = prefs.getInt(_keyLastUpdate) ?? 0;
      final elapsed   = DateTime.now().millisecondsSinceEpoch - lastCheck;
      if (elapsed < const Duration(hours: 24).inMilliseconds) {
        debugPrint('[OtyaService] Update check skipped — within 24 h window.');
        return;
      }
    }

    final checkUpdateUri     = Uri.parse(_checkUpdateUrl);
    final checkUpdateHeaders = ApiSigner.signedHeaders(
      method: 'GET',
      path: checkUpdateUri.path,
    );
    http.Response? response;
    try {
      response = await http
          .get(checkUpdateUri, headers: checkUpdateHeaders)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[OtyaService] Update check network error: $e');
      return;
    }

    if (response.statusCode != 200) {
      debugPrint('[OtyaService] Update check returned ${response.statusCode}.');
      return;
    }

    await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('[OtyaService] Update response is not valid JSON.');
      return;
    }

    final remoteBuild  = (data['versionCode']   as num?)?.toInt()
                      ?? (data['build_number']  as num?)?.toInt()
                      ?? 0;
    final forceUpdate  = (data['force_update']  as bool?) ?? false;
    final releaseNotes = (data['changelog']     as String?)
                      ?? (data['release_notes'] as String?)
                      ?? 'Bug fixes and improvements.';
    final downloadUrl  = (data['download_url']  as String?) ?? Environment.downloadUrl;

    if (remoteBuild == 0) {
      debugPrint('[OtyaService] Remote versionCode missing or zero — skipping.');
      return;
    }

    final packageInfo    = await PackageInfo.fromPlatform();
    final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    debugPrint('[OtyaService] Installed: $installedBuild  Remote: $remoteBuild');

    if (remoteBuild <= installedBuild) {
      debugPrint('[OtyaService] App is up to date.');
      return;
    }

    if (!context.mounted) return;

    showDialog<void>(
      context:            context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => _UpdateDialog(
        releaseNotes: releaseNotes,
        downloadUrl:  downloadUrl,
        forceUpdate:  forceUpdate,
        remoteBuild:  remoteBuild,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────────
  // registerDevicePushToken
  // ─────────────────────────────────────────────────────────────────────────────────
  Future<void> registerDevicePushToken({
    required String deviceId,
    required String fcmToken,
  }) async {
    try {
      const path = '/api/device';
      final headers = {
        ...ApiSigner.signedHeaders(method: 'POST', path: path, deviceId: deviceId),
        'Content-Type': 'application/json',
      };
      final response = await http
          .post(
            Uri.parse('${Environment.workerUrl}$path'),
            headers: headers,
            body: jsonEncode({'device_id': deviceId, 'fcm_token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[OtyaService] Push token registered for device $deviceId.');
      } else {
        debugPrint('[OtyaService] registerDevicePushToken returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[OtyaService] registerDevicePushToken failed (non-fatal): $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────────
// _UpdateDialog
// ─────────────────────────────────────────────────────────────────────────────────
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.remoteBuild,
  });

  final String releaseNotes;
  final String downloadUrl;
  final bool   forceUpdate;
  final int    remoteBuild;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceUpdate,
      child: AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Update Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, fontFamily: 'Inter')),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.forceUpdate) ..._forceUpdateBanner(),
            const SizedBox(height: 12),
            const Text("What's new",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary, fontFamily: 'Inter', letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(widget.releaseNotes,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary,
                  fontFamily: 'Inter', height: 1.5)),
            if (_downloading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text('Downloading… check the notification bar for progress.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Inter')),
            ],
          ],
        ),
        actions: [
          if (!widget.forceUpdate && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later',
                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Inter')),
            ),
          ElevatedButton.icon(
            onPressed: _downloading ? null : () => _launchDownload(context),
            icon: _downloading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(_downloading ? 'Downloading…' : 'Download'),
          ),
        ],
      ),
    );
  }

  List<Widget> _forceUpdateBanner() => [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text('This update is required to continue using Otya Player.',
              style: TextStyle(fontSize: 12, color: AppColors.error,
                  fontFamily: 'Inter', height: 1.4)),
          ),
        ],
      ),
    ),
  ];

  Future<void> _launchDownload(BuildContext context) async {
    if (widget.downloadUrl.isEmpty) return;
    setState(() => _downloading = true);
    await PushNotificationService.instance.showDownloadProgress(percent: 0);
    final version = widget.remoteBuild.toString();
    await ApkDownloader.instance.downloadAndInstall(
      url:     widget.downloadUrl,
      version: version,
      onProgress: (p) =>
          PushNotificationService.instance.showDownloadProgress(percent: (p * 100).round()).ignore(),
      onError: (err) {
        debugPrint('[OtyaService] Download error: $err');
        PushNotificationService.instance.dismissDownload().ignore();
        if (mounted) {
          setState(() => _downloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $err')),
          );
        }
      },
    );
    await PushNotificationService.instance.showDownloadComplete();
    if (mounted) {
      setState(() => _downloading = false);
      if (!widget.forceUpdate) Navigator.of(context).pop();
    }
  }
}
