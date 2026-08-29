import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/app_colors.dart';

/// Contextual permission helper — request permissions only when the feature
/// that needs them is actually opened by the user.
class PermissionHelper {
  PermissionHelper._();

  static int? _sdkInt;

  static Future<int> _getSdkInt() async {
    if (_sdkInt != null) return _sdkInt!;
    if (!Platform.isAndroid) return 0;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _sdkInt = info.version.sdkInt;
    } catch (_) {
      _sdkInt = 30;
    }
    return _sdkInt!;
  }

  /// Request Android permissions needed to discover the local media library.
  ///
  /// Android 13+ uses the split audio/video permissions. Android 12 and below
  /// use READ_EXTERNAL_STORAGE. OTYA never requests broad all-files access.
  static Future<bool> requestMediaPermissions({BuildContext? context}) async {
    final sdk = await _getSdkInt();
    if (sdk == 0) return true;

    final permissions = sdk >= 33
        ? [Permission.audio, Permission.videos]
        : [Permission.storage];
    final statuses = await permissions.request();

    if (context != null && context.mounted) {
      for (final status in statuses.values) {
        if (status.isPermanentlyDenied) {
          await showPermanentlyDeniedDialog(
            context,
            permissionName: 'Media access',
            rationale:
                'OTYA needs Android media access to discover the songs and videos on this phone. Open Settings to grant the permission.',
          );
          break;
        }
      }
    }

    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  /// Check without prompting whether OTYA can currently read both audio and
  /// video. Limited status is accepted where Android exposes it.
  static Future<bool> hasMediaPermissions() async {
    final sdk = await _getSdkInt();
    if (sdk == 0) return true;
    if (sdk >= 33) {
      final audio = await Permission.audio.status;
      final videos = await Permission.videos.status;
      return (audio.isGranted || audio.isLimited) &&
          (videos.isGranted || videos.isLimited);
    }
    final storage = await Permission.storage.status;
    return storage.isGranted || storage.isLimited;
  }

  /// Show recovery UI for a permission Android will no longer prompt for.
  static Future<bool> showPermanentlyDeniedDialog(
    BuildContext context, {
    String permissionName = 'Permission',
    String? rationale,
  }) async {
    final opened = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$permissionName required',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        content: Text(
          rationale ??
              'This permission has been permanently denied. Open Android Settings to grant it manually.',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext, true);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return opened ?? false;
  }

  /// Branded rationale that can be shown before Android's system media prompt.
  static Future<bool> showMediaPermissionRationale(BuildContext context) async {
    final granted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardOf(context),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: AppColors.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Show your media library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'OTYA needs Android media access to find music and videos already on this phone. Building your local library does not upload those files.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final ok = await requestMediaPermissions();
                  if (sheetContext.mounted) Navigator.pop(sheetContext, ok);
                },
                icon: const Icon(Icons.library_music_rounded),
                label: const Text('Allow media access'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
    return granted ?? false;
  }
}
