import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/widgets/played_logo.dart';

/// Shown on first launch. Requests all required runtime permissions.
///
/// Permission tiers:
///   CRITICAL  — storage/media. App cannot scan files without these.
///   IMPORTANT — MANAGE_EXTERNAL_STORAGE (Android 11+). Needed to index
///               files on SD cards and in non-standard folders.
///   OPTIONAL  — Bluetooth, Location, Notifications. Only needed for
///               Air-Drop. App works fine without them.
///   BATTERY   — Battery optimisation exemption.
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

  // Android 13+ uses granular media permissions.
  // Android ≤ 12 uses the legacy READ_EXTERNAL_STORAGE (Permission.storage).
  // We request both sets and accept whichever is applicable on the device.
  static final List<Permission> _criticalAndroid13 = [
    Permission.audio,
    Permission.videos,
  ];
  static final List<Permission> _criticalLegacy = [
    Permission.storage,
  ];

  // Optional — only needed for Air-Drop; never blocks the app
  static final List<Permission> _optional = [
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

  /// Re-check when user returns from system Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_criticalGranted) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    setState(() => _checking = true);

    // ── Step 1: Critical permissions ────────────────────────────────────
    // On Android 13+ (SDK 33+), READ_EXTERNAL_STORAGE is deprecated and
    // always returns 'denied' even when granted. We detect the SDK version
    // and only check the permissions that actually apply.
    final isAndroid13Plus = Platform.isAndroid &&
        (await _getAndroidSdkVersion()) >= 33;

    Map<Permission, PermissionStatus> criticalStatuses;

    if (isAndroid13Plus) {
      // Android 13+: request granular media permissions only
      criticalStatuses = await _criticalAndroid13.request();
    } else {
      // Android ≤ 12: request legacy storage permission
      criticalStatuses = await _criticalLegacy.request();
    }

    // ── Step 2: Optional permissions (fire-and-forget, never blocks) ────
    // Request silently in background — result is ignored
    _optional.request().ignore();

    // ── Step 3: MANAGE_EXTERNAL_STORAGE (Android 11+) ────────────────
    if (Platform.isAndroid) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        _promptManageStorage();
      }
    }

    // ── Step 4: Battery optimisation exemption ───────────────────────
    await _requestBatteryExemption();

    // ── Evaluate result ──────────────────────────────────────────────
    final criticalGranted = criticalStatuses.values.every(
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

  /// Returns the Android SDK version (e.g. 33 for Android 13).
  Future<int> _getAndroidSdkVersion() async {
    try {
      // permission_handler exposes this via the OS info
      // Fallback: read from system property via Process
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 30;
    } catch (_) {
      return 30; // safe fallback — treat as Android 11
    }
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

  static final Map<Permission, String> _labels = {
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
          // Subtle radial glow
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

                  // Logo
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

                  // Recommendations card
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

                  // Denied permissions list
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

                  // Open App Settings (secondary)
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

                  // Primary action button
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
