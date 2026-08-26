import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';
import '../../../app/theme/app_colors.dart';

// ── App Lock Provider ───────────────────────────────────────────

final appLockedProvider = StateProvider<bool>((_) => true);
final appLockEnabledProvider = StateProvider<bool>((_) => false);

// ── App Lock Gate ─────────────────────────────────────────────

/// Wraps the entire app. Shows lock screen when app lock is enabled.
class AppLockGate extends ConsumerWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(appLockEnabledProvider);
    final isLocked = ref.watch(appLockedProvider);

    if (!lockEnabled || !isLocked) return child;
    return AppLockScreen(
      onUnlocked: () =>
          ref.read(appLockedProvider.notifier).state = false,
    );
  }
}

// ── App Lock Screen ───────────────────────────────────────────

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _authenticating = false;
  String? _error;
  // PIN unlock is not configured — biometrics only.
  // To add PIN support, integrate a secure storage solution (e.g. flutter_secure_storage)
  // and store/retrieve the PIN hash there instead of hardcoding it.
  bool _showPinUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() { _authenticating = true; _error = null; });
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock OTYA Player',
        options: const AuthenticationOptions(
            biometricOnly: false, stickyAuth: true),
      );
      if (ok) { widget.onUnlocked(); }
      else { setState(() => _error = 'Authentication failed.'); }
    } catch (_) {
      setState(() => _showPinUnavailable = true);
    } finally {
      setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Text('OTYA',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    fontFamily: 'SpaceGrotesk',
                    letterSpacing: 6,
                  )).animate().fadeIn(duration: 500.ms),

              const SizedBox(height: 48),

              // Lock icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4)
                  ],
                ),
                child: const Icon(Icons.lock_rounded,
                    color: AppColors.accent, size: 36),
              ).animate().scale(
                    begin: const Offset(0.8, 0.8),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 32),

              if (_showPinUnavailable) ...
                [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.textSecondary, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'PIN unlock not configured. Please use biometrics.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontFamily: 'SpaceGrotesk',
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _authenticate,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fingerprint_rounded,
                              color: Colors.black, size: 22),
                          SizedBox(width: 8),
                          Text('Try Biometrics Again',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                fontFamily: 'SpaceGrotesk',
                              )),
                        ],
                      ),
                    ),
                  ),
                ]
              else if (_authenticating)
                const CircularProgressIndicator(color: AppColors.accent)
              else
                GestureDetector(
                  onTap: _authenticate,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint_rounded,
                            color: Colors.black, size: 22),
                        SizedBox(width: 8),
                        Text('Unlock',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              fontFamily: 'SpaceGrotesk',
                            )),
                      ],
                    ),
                  ),
                ),

              if (_error != null) ...
                [
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ],


            ],
          ),
        ),
      ),
    );
  }
}
