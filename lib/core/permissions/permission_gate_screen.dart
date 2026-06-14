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

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _criticalGranted = false;
  bool _hasPermanentlyDenied = false;
  Map<Permission, PermissionStatus> _statuses = {};

  // Critical — app cannot scan media without these
  static final List<Permission> _critical = [
    Permission.storage, // Android ≤ 12
    Permission.audio, // Android 13+
    Permission.videos, // Android 13+
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
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions when the user returns from system Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_criticalGranted) {
      _checkPermissions();
    }
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
        .every((s) =>
            s == PermissionStatus.granted || s == PermissionStatus.limited);

    final hasPermanentlyDenied = criticalStatuses.values
        .any((s) => s == PermissionStatus.permanentlyDenied);

    setState(() {
      _statuses = criticalStatuses;
      _criticalGranted = criticalGranted;
      _hasPermanentlyDenied = hasPermanentlyDenied;
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
      hasPermanentlyDenied: _hasPermanentlyDenied,
      onRetry: _checkPermissions,
    );
  }
}

// ── Shared Branding Widgets ────────────────────────────────────

class _PlayedLogo extends StatelessWidget {
  const _PlayedLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.accent.withValues(alpha: 0.05),
      ),
      child: const Text(
        'PLAYED',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          fontFamily: 'Inter',
          letterSpacing: 6,
        ),
      ),
    );
  }
}

class _PoweredByFooter extends StatelessWidget {
  const _PoweredByFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        'from PeterSmart Technologies',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
        ),
      ),
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PlayedLogo()
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
            const _PoweredByFooter(),
          ],
        ),
      ),
    );
  }
}

// ── Permission Denied Screen ──────────────────────────────────

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
    Permission.audio: 'Audio files — read music (Android 13+)',
    Permission.videos: 'Video files — read videos (Android 13+)',
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
          // Subtle radial glow behind the logo
          Positioned(
            top: -60,
            left: 0,
            right: 0,
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

                  // ── Logo + Title (centred) ──
                  const Center(child: _PlayedLogo()),
                  const SizedBox(height: 20),
                  const Text(
                    'Storage Access Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'PLAYED needs access to your media files to work.\n'
                    'Bluetooth and Location are optional — only needed for Air-Drop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Recommendations card ──
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
                        Text(
                          'For best results also grant:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• All Files Access\n'
                          '  Settings → Apps → PLAYED → Permissions\n'
                          '• Unrestricted battery usage\n'
                          '  Settings → Battery → PLAYED',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.6,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Denied permissions list ──
                  Expanded(
                    child: ListView(
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
                                  // Coloured left bar
                                  Container(
                                    width: 4,
                                    color: barColor,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isPermanent
                                                ? Icons.block_rounded
                                                : Icons.warning_amber_rounded,
                                            color: barColor,
                                            size: 18,
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
                                              child: const Text(
                                                'Settings',
                                                style: TextStyle(
                                                  color: AppColors.accent,
                                                  fontSize: 12,
                                                ),
                                              ),
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

                  // ── Open App Settings (secondary) ──
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
                          Text(
                            'Open App Settings',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Primary action button ──
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
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        hasPermanentlyDenied
                            ? 'Open Settings to Grant Access'
                            : 'Grant Storage Access',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          fontFamily: 'Inter',
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
                  const _PoweredByFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
