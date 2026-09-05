import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/otya_logo.dart';
import '../../shared/widgets/wallpaper_scaffold.dart';
import 'settings_provider.dart';

/// Application-level privacy gate.
///
/// [settingsProvider] is the single source of truth for whether App Lock is
/// enabled. The unlocked state is deliberately session-only: whenever OTYA
/// leaves the foreground it locks again, while the user's enabled preference
/// remains persisted by [AppSettings].
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _unlockedForSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_unlockedForSession && mounted) {
        setState(() => _unlockedForSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      settingsProvider.select((settings) => settings.appLockEnabled),
      (previous, enabled) {
        if (!enabled && _unlockedForSession && mounted) {
          setState(() => _unlockedForSession = false);
        }
      },
    );

    final enabled = ref.watch(settingsProvider.select((s) => s.appLockEnabled));
    if (!enabled) return widget.child;
    if (_unlockedForSession) return widget.child;
    return AppLockScreen(
      onUnlocked: () {
        if (mounted) setState(() => _unlockedForSession = true);
      },
    );
  }
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        if (mounted) {
          setState(() => _error =
              'Device authentication is not configured. Set a screen lock in Android settings to use App Lock.');
        }
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock OTYA',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) {
        widget.onUnlocked();
      } else if (mounted) {
        setState(() => _error = 'OTYA stayed locked. Try again to continue.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Device authentication is unavailable right now. Try again or check Android security settings.');
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WallpaperScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OtyaMark(size: 36),
                    SizedBox(width: 11),
                    Text(
                      'Otya',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        letterSpacing: -.8,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 350.ms),
                const SizedBox(height: 42),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.brandCyan, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandBlue.withValues(alpha: .24),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.brandCyan,
                    size: 36,
                  ),
                ).animate().scale(
                      begin: const Offset(.88, .88),
                      duration: 300.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 24),
                const Text(
                  'Otya is locked',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use your device screen lock, fingerprint or face authentication to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _authenticating ? null : _authenticate,
                    icon: _authenticating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(_authenticating ? 'Checking…' : 'Unlock Otya'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
