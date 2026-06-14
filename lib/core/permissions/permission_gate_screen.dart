import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/widgets/played_logo.dart';

// Cached SDK version so we only call device_info_plus once per session.
int? _cachedSdkInt;

/// Returns the Android SDK version integer (e.g. 36 for Android 16).
/// Uses device_info_plus which reads via the proper platform channel.
/// Result is cached after the first call.
Future<int> _androidSdkVersion() async {
  if (_cachedSdkInt != null) return _cachedSdkInt!;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    _cachedSdkInt = info.version.sdkInt;
  } catch (_) {
    _cachedSdkInt = 30; // safe fallback
  }
  return _cachedSdkInt!;
}

/// Shown on first launch (and whenever critical permissions are missing).
/// Requests the correct permissions for the running Android version:
///
///   Android ≤ 12 (SDK ≤ 32): READ_EXTERNAL_STORAGE (Permission.storage)
///   Android 13+  (SDK ≥ 33): READ_MEDIA_AUDIO + READ_MEDIA_VIDEO
///
/// The legacy Permission.storage is ALWAYS denied on Android 13+ even
/// after the user grants it — that is why the app was stuck on Android 16.
class PermissionGateScreen extends StatefulWidget {
  final Widget child;
  const PermissionGateScreen({super.key, required this.child});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _criticalGranted = false;
  bool _hasPermanentlyDenied = false;
  Map<Permission, PermissionStatus> _statuses = {};

  // Optional — only needed for Air-Drop; never blocks the app
  static const List<Permission> _optional = [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
    Permission.nearbyWifiDevices,
    Permission.notification,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check every time the user comes back from system Settings.
    if (state == AppLifecycleState.resumed && !_criticalGranted) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    setState(() => _checking = true);

    // ── 1. Determine which critical permissions apply on this device ──────
    final sdk = Platform.isAndroid ? await _androidSdkVersion() : 0;

    // Android 13+ (SDK 33+): granular media permissions
    // Android 12 and below: legacy READ_EXTERNAL_STORAGE
    // iOS / other: no storage permission needed
    final List<Permission> critical;
    if (sdk >= 33) {
      critical = [Permission.audio, Permission.videos];
    } else if (sdk > 0) {
      critical = [Permission.storage];
    } else {
      critical = []; // iOS — no runtime storage permission
    }

    // ── 2. Request critical permissions ────────────────────────────────
    final Map<Permission, PermissionStatus> criticalStatuses;
    if (critical.isEmpty) {
      criticalStatuses = {};
    } else {
      criticalStatuses = await critical.request();
    }

    // ── 3. Optional permissions — fire-and-forget, never blocks ──────────
    _optional.request().ignore();

    // ── 4. MANAGE_EXTERNAL_STORAGE prompt (Android 11+, non-blocking) ───
    if (sdk >= 30) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) _promptManageStorage();
    }

    // ── 5. Battery optimisation exemption ────────────────────────────
    await _requestBatteryExemption();

    // ── 6. Evaluate ──────────────────────────────────────────────────
    // If there are no critical permissions (iOS), treat as granted.
    final criticalGranted = criticalStatuses.isEmpty ||
        criticalStatuses.values.every(
          (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
        );
    final hasPermanentlyDenied = criticalStatuses.values
        .any((s) => s == PermissionStatus.permanentlyDenied);

    if (!mounted) return;
    setState(() {
      _statuses = criticalStatuses;
      _criticalGranted = criticalGranted;
      _hasPermanentlyDenied = hasPermanentlyDenied;
      _checking = false;
    });
  }

  Future<void> _requestBatteryExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {}
  }

  void _promptManageStorage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 8),
          content: const Text(
            'For full SD card access, grant "All Files Access" in Settings.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            textColor: AppColors.accent,
            onPressed: openAppSettings,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashLoader();
    if (_criticalGranted) return widget.child;
    return _PermissionDeniedScreen(
      statuses: _statuses,
      hasPermanentlyDenied: _hasPermanentlyDenied,
      onRetry: _checkPermissions,
    );
  }
}

// ── Splash Loader ─────────────────────────────────────────────────

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PlayedLogo()
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.1),
                    const SizedBox(height: 12),
                    const Text(
                      'Your media. Your rules.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Setting up...',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                  ],
                ),
              ),
            ),
            const PlayedFooter(),
          ],
        ),
      ),
    );
  }
}

// ── Permission Denied Screen ───────────────────────────────────────

class _PermissionDeniedScreen extends StatelessWidget {
  final Map<Permission, PermissionStatus> statuses;
  final bool hasPermanentlyDenied;
  final VoidCallback onRetry;

  const _PermissionDeniedScreen({
    required this.statuses,
    required this.hasPermanentlyDenied,
    required this.onRetry,
  });

  static const Map<Permission, String> _labels = {
    Permission.storage: 'Storage — scan local media files (Android ≤ 12)',
    Permission.audio:   'Audio files — read music (Android 13+)',
    Permission.videos:  'Video files — read videos (Android 13+)',
  };

  @override
  Widget build(BuildContext context) {
    final denied = statuses.entries
        .where((e) =>
            _labels.containsKey(e.key) &&
            (e.value == PermissionStatus.denied ||
                e.value == PermissionStatus.permanentlyDenied))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -60, left: 0, right: 0,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Center(child: PlayedLogo()),
                  const SizedBox(height: 20),
                  const Text(
                    'Storage Access Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'PLAYED needs access to your media files to work.\n'
                    'Bluetooth and Location are optional — only needed for Air-Drop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary,
                      height: 1.5, fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('For best results also grant:',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary, fontFamily: 'Inter',
                            )),
                        SizedBox(height: 6),
                        Text(
                          '• All Files Access\n'
                          '  Settings → Apps → PLAYED → Permissions\n'
                          '• Unrestricted battery usage\n'
                          '  Settings → Battery → PLAYED',
                          style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary,
                            height: 1.6, fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: denied.isEmpty
                        ? const Center(
                            child: Text(
                              'Tap the button below to grant access.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          )
                        : ListView(
                            children: denied.map((e) {
                              final isPermanent =
                                  e.value == PermissionStatus.permanentlyDenied;
                              final barColor =
                                  isPermanent ? Colors.redAccent : Colors.amber;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isPermanent
                                        ? Colors.redAccent.withValues(alpha: 0.35)
                                        : AppColors.border,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Container(width: 4, color: barColor),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isPermanent
                                                      ? Icons.block_rounded
                                                      : Icons.warning_amber_rounded,
                                                  color: barColor, size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _labels[e.key] ??
                                                        e.key.toString(),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors.textPrimary,
                                                      fontFamily: 'Inter',
                                                    ),
                                                  ),
                                                ),
                                                if (isPermanent)
                                                  TextButton(
                                                    onPressed: openAppSettings,
                                                    child: const Text('Settings',
                                                        style: TextStyle(
                                                          color: AppColors.accent,
                                                          fontSize: 12,
                                                        )),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: openAppSettings,
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings_rounded,
                              color: AppColors.textSecondary, size: 18),
                          SizedBox(width: 8),
                          Text('Open App Settings',
                              style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary,
                                fontFamily: 'Inter',
                              )),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: hasPermanentlyDenied ? openAppSettings : onRetry,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentViolet],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 18, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        hasPermanentlyDenied
                            ? 'Open Settings to Grant Access'
                            : 'Grant Storage Access',
                        style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.black, fontFamily: 'Inter',
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          duration: 2000.ms,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                  ),
                  const SizedBox(height: 12),
                  const PlayedFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
