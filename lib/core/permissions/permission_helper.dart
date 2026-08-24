import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme/app_colors.dart';

/// Contextual permission helper — request permissions only when the
/// feature that needs them is actually opened by the user.
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

  /// Request storage/media permissions needed for media scanning.
  /// Returns true if granted.
  ///
  /// Android 13+ (API 33+): requests READ_MEDIA_AUDIO + READ_MEDIA_VIDEO
  ///   (Permission.audio + Permission.videos via permission_handler).
  /// Android 12 and below: requests READ_EXTERNAL_STORAGE (Permission.storage).
  ///
  /// The AndroidManifest.xml declares both sets with appropriate maxSdkVersion
  /// constraints so the correct permission is used on each Android version.
  static Future<bool> requestMediaPermissions() async {
    final sdk = await _getSdkInt();
    if (sdk == 0) return true; // iOS — no runtime permission needed
    final perms = sdk >= 33
        ? [Permission.audio, Permission.videos]  // Android 13+ (Bug 6 fix)
        : [Permission.storage];                  // Android 12 and below
    final statuses = await perms.request();
    return statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );
  }

  /// Check (without requesting) if media permissions are already granted.
  static Future<bool> hasMediaPermissions() async {
    final sdk = await _getSdkInt();
    if (sdk == 0) return true;
    final perms = sdk >= 33
        ? [Permission.audio, Permission.videos]
        : [Permission.storage];
    for (final p in perms) {
      final s = await p.status;
      if (!s.isGranted && !s.isLimited) return false;
    }
    return true;
  }

  /// Request Air-Drop permissions (Bluetooth + Location/NearbyWifi).
  ///
  /// On Android 13+ (API >= 33) we request [Permission.nearbyWifiDevices]
  /// instead of location — the manifest declares NEARBY_WIFI_DEVICES with
  /// `neverForLocation` so no location access is granted.
  /// On Android 12 and below (API <= 32) we keep requesting location because
  /// NEARBY_WIFI_DEVICES is not available and Wi-Fi P2P requires it.
  static Future<void> requestAirDropPermissions() async {
    final sdk = await _getSdkInt();
    final perms = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];
    if (sdk >= 33) {
      perms.add(Permission.nearbyWifiDevices);
    } else {
      perms.add(Permission.locationWhenInUse);
    }
    await perms.request();
  }

  /// Show a branded bottom sheet explaining why storage permission is needed,
  /// then request it. Returns true if granted.
  static Future<bool> showMediaPermissionRationale(BuildContext context) async {
    final granted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.folder_open_rounded,
                  color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Allow Media Access',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'OTYA Player needs access to your audio and video files to show your library. '
              'No files are uploaded or shared.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 28),
            // Grant button
            GestureDetector(
              onTap: () async {
                final ok = await requestMediaPermissions();
                if (ctx.mounted) Navigator.pop(ctx, ok);
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentViolet],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Allow Access',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Not now
            GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return granted ?? false;
  }
}
