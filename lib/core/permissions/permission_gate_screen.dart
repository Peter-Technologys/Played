import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme/app_colors.dart';

/// Shown on first launch. Requests all required runtime permissions.
///
/// Permission tiers:
///   CRITICAL  — storage/media. App cannot scan files without these.
///   IMPORTANT — MANAGE_EXTERNAL_STORAGE (Android 11+). Needed to index
///               files on SD cards and in non-standard folders. Redirects
///               to system settings (cannot be requested inline).
///   OPTIONAL  — Bluetooth, Location, Notifications. Only needed for
///               Air-Drop. App works fine without them.
///   BATTERY   — Battery optimisation exemption. Prevents Android from
///               killing the background playback service.
class PermissionGateScreen extends StatefulWidget {
  final Widget child;
  const PermissionGateScreen({super.key, required this.child});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _checking = true;
  bool _criticalGranted = false;
  Map<Permission, PermissionStatus> _statuses = {};

  // Critical — app cannot scan media without these
  static final List<Permission> _critical = [
    Permission.storage,  // Android ≤ 12
    Permission.audio,    // Android 13+
    Permission.videos,   // Android 13+
  ];

  // Optional — only needed for Air-Drop; app works fine without them
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
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checking = true);

    // 1. Critical permissions
    final criticalStatuses = await _critical.request();

    // 2. Optional permissions (result never blocks the app)
    await _optional.request();

    // 3. MANAGE_EXTERNAL_STORAGE — Android 11+ only, cannot be requested
    //    inline; we check and prompt the user to go to Settings if needed.
    if (Platform.isAndroid) {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        // Non-blocking: show a one-time banner after the gate passes
        _promptManageStorage();
      }
    }

    // 4. Battery optimisation exemption
    await _requestBatteryExemption();

    final criticalGranted = criticalStatuses.values
        .every((s) => s == PermissionStatus.granted ||
            s == PermissionStatus.limited);

    setState(() {
      _statuses = criticalStatuses;
      _criticalGranted = criticalGranted;
      _checking = false;
    });
  }

  /// Requests battery optimisation exemption so Android never kills
  /// the background playback service (Unrestricted battery mode).
  Future<void> _requestBatteryExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {
      // Not available on all OEMs — ignore silently
    }
  }

  /// Shows a non-blocking snackbar prompting the user to grant
  /// MANAGE_EXTERNAL_STORAGE via system Settings.
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
      onRetry: _checkPermissions,
    );
  }
}

// ── Splash Loader ─────────────────────────────────────────────

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PLAYED',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFamily: 'SpaceGrotesk',
                letterSpacing: 6,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
            const SizedBox(height: 8),
            Text(
              'Your media. Your rules.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'SpaceGrotesk',
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            Text(
              'Setting up...',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

// ── Permission Denied Screen ──────────────────────────────────

class _PermissionDeniedScreen extends StatelessWidget {
  final Map<Permission, PermissionStatus> statuses;
  final VoidCallback onRetry;
  const _PermissionDeniedScreen(
      {required this.statuses, required this.onRetry});

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.folder_off_rounded,
                  color: AppColors.accent, size: 48),
              const SizedBox(height: 20),
              const Text(
                'Storage Access Required',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'SpaceGrotesk',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'PLAYED needs access to your media files to work.\n'
                'Bluetooth and Location are optional — only needed for Air-Drop.\n\n'
                'For best results also grant:\n'
                '• All Files Access (Settings → Apps → PLAYED → Permissions)\n'
                '• Unrestricted battery usage (Settings → Battery → PLAYED)',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: denied.map((e) {
                    final isPermanent =
                        e.value == PermissionStatus.permanentlyDenied;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPermanent
                              ? Colors.redAccent.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPermanent
                                ? Icons.block_rounded
                                : Icons.warning_amber_rounded,
                            color: isPermanent
                                ? Colors.redAccent
                                : Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _labels[e.key] ?? e.key.toString(),
                              style: const TextStyle(
                                fontSize: 13, color: AppColors.textPrimary,
                                fontFamily: 'SpaceGrotesk',
                              ),
                            ),
                          ),
                          if (isPermanent)
                            TextButton(
                              onPressed: openAppSettings,
                              child: const Text('Open Settings',
                                  style: TextStyle(
                                      color: AppColors.accent, fontSize: 12)),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Open Settings shortcut for permanently denied
              GestureDetector(
                onTap: openAppSettings,
                child: Container(
                  width: double.infinity,
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
                            fontFamily: 'SpaceGrotesk',
                          )),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRetry,
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
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 16, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Grant Storage Access',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.black, fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
