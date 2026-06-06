import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
// Fixed import path: file is in lib/core/permissions/, so needs two levels up
import '../../app/theme/app_colors.dart';

/// Shown on first launch. Requests all required runtime permissions
/// before allowing the user into the main app.
class PermissionGateScreen extends StatefulWidget {
  final Widget child;
  const PermissionGateScreen({super.key, required this.child});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _checking = true;
  bool _allGranted = false;
  Map<Permission, PermissionStatus> _statuses = {};

  // All permissions the app needs
  static final List<Permission> _required = [
    Permission.storage,
    Permission.audio,
    Permission.videos,
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
    final statuses = await _required.request();
    final allGranted = statuses.values
        .every((s) => s == PermissionStatus.granted ||
            s == PermissionStatus.limited);
    setState(() {
      _statuses = statuses;
      _allGranted = allGranted;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashLoader();
    if (_allGranted) return widget.child;
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
            // App logo / wordmark
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
            SizedBox(
              width: 32,
              height: 32,
              child: const CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
            const SizedBox(height: 16),
            Text(
              'Requesting permissions...',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
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

  const _PermissionDeniedScreen({
    required this.statuses,
    required this.onRetry,
  });

  // Non-const: Permission overrides == and hashCode so cannot be used as a const map key
  static final Map<Permission, String> _labels = {
    Permission.storage: 'Storage — scan local media files',
    Permission.audio: 'Audio files — read music',
    Permission.videos: 'Video files — read videos',
    Permission.bluetooth: 'Bluetooth — Air-Drop sharing',
    Permission.bluetoothScan: 'Bluetooth Scan — find nearby devices',
    Permission.bluetoothAdvertise: 'Bluetooth Advertise — be discoverable',
    Permission.bluetoothConnect: 'Bluetooth Connect — transfer files',
    Permission.locationWhenInUse: 'Location — required for Bluetooth scan',
    Permission.nearbyWifiDevices: 'Nearby Wi-Fi — high-speed Air-Drop',
    Permission.notification: 'Notifications — extraction progress',
  };

  @override
  Widget build(BuildContext context) {
    final denied = statuses.entries
        .where((e) =>
            e.value == PermissionStatus.denied ||
            e.value == PermissionStatus.permanentlyDenied)
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
              const Icon(Icons.security_rounded,
                  color: AppColors.accent, size: 48),
              const SizedBox(height: 20),
              const Text(
                'Permissions Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'PLAYED needs the following permissions to work fully offline.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
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
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontFamily: 'SpaceGrotesk',
                              ),
                            ),
                          ),
                          if (isPermanent)
                            TextButton(
                              onPressed: openAppSettings,
                              child: const Text(
                                'Settings',
                                style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
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
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Grant Permissions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'SpaceGrotesk',
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
