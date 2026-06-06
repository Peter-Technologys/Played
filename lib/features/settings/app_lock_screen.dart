import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _pinController = TextEditingController();
  bool _showPin = false;
  static const String _appPin = '0000'; // Replace with secure storage

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() { _authenticating = true; _error = null; });
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock PLAYED',
        options: const AuthenticationOptions(
            biometricOnly: false, stickyAuth: true),
      );
      if (ok) widget.onUnlocked();
      else setState(() => _error = 'Authentication failed.');
    } catch (_) {
      setState(() => _showPin = true);
    } finally {
      setState(() => _authenticating = false);
    }
  }

  void _verifyPin() {
    if (_pinController.text == _appPin) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Wrong PIN. Try again.');
      _pinController.clear();
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
              Text('PLAYED',
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
                        color: AppColors.accent.withOpacity(0.3),
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

              if (_showPin) ...
                [
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        letterSpacing: 8),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '• • • •',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 24),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.accent)),
                    ),
                    onSubmitted: (_) => _verifyPin(),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _verifyPin,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Unlock',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            fontFamily: 'SpaceGrotesk',
                          )),
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

              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    setState(() => _showPin = !_showPin),
                child: Text(
                  _showPin ? 'Use Biometrics' : 'Use PIN instead',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'SpaceGrotesk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
