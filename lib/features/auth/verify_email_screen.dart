// lib/features/auth/verify_email_screen.dart
//
// Shows after registration if email not verified.
// OTP input (5 chars, A1234 format), resend button (60s cooldown), submit.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;
  DateTime? _resendAvailableAt;
  Timer? _timer;
  int _requestGeneration = 0;

  int get _cooldown {
    final deadline = _resendAvailableAt;
    if (deadline == null) return 0;
    final seconds = deadline.difference(DateTime.now()).inSeconds + 1;
    return seconds.clamp(0, 60);
  }

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _requestGeneration++;
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 0) {
        timer.cancel();
        _timer = null;
        setState(() => _resendAvailableAt = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_cooldown > 0 || _loading) return;
    final generation = ++_requestGeneration;
    setState(() {
      _error = null;
      _success = null;
      _loading = true;
    });

    bool sent = false;
    try {
      sent = await AuthService.instance
          .sendVerificationOtp()
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      sent = false;
    } catch (_) {
      sent = false;
    }
    if (!mounted || generation != _requestGeneration) return;

    if (!sent) {
      setState(() {
        _loading = false;
        _error = 'We could not send the verification code. Check your connection and try again.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _success = 'If your account can receive verification mail, a code has been sent.';
    });
    _startCooldown();
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z][0-9]{4}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 5-character code from your email, e.g. A1234.');
      return;
    }

    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    bool ok = false;
    try {
      ok = await AuthService.instance
          .verifyOtp(otp)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _loading = false;
          _error = 'Verification timed out. Check your connection and try again.';
        });
      }
      return;
    } catch (_) {
      ok = false;
    }
    if (!mounted || generation != _requestGeneration) return;

    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email verified! ✓'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/');
    } else {
      setState(() => _error = 'Invalid or expired code. Request a new one.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cooldown = _cooldown;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: scheme.onSurfaceVariant, size: 20),
          onPressed: _loading ? null : () => context.pop(),
        ),
        title: Text(
          'Verify Email',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: scheme.onSurface, fontFamily: 'Inter'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread_outlined, color: AppColors.accent, size: 56),
              const SizedBox(height: 20),
              Text('Check your email', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: scheme.onSurface, fontFamily: 'Inter')),
              const SizedBox(height: 8),
              Text('We sent a 5-character code to your email address.\nEnter it below to verify your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14,
                      fontFamily: 'Inter', height: 1.5)),
              const SizedBox(height: 32),
              TextField(
                controller: _otpCtrl,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text,
                maxLength: 5,
                enabled: !_loading,
                textAlign: TextAlign.center,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                onSubmitted: (_) { if (!_loading) _verify(); },
                style: TextStyle(color: scheme.onSurface, fontFamily: 'Inter',
                    fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: 'A1234',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                      fontSize: 28, letterSpacing: 8, fontFamily: 'Inter'),
                  counterText: '', filled: true, fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: scheme.outlineVariant)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: scheme.outlineVariant)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
                  child: Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error, fontSize: 13, fontFamily: 'Inter'))),
              ],
              if (_success != null) ...[
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                  child: Text(_success!, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.success, fontSize: 13, fontFamily: 'Inter'))),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _verify,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.accent, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent))
                    : const Text('Verify Email', style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 15, fontFamily: 'Inter')),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: (cooldown > 0 || _loading) ? null : _sendOtp,
                child: Text(cooldown > 0 ? 'Resend code in ${cooldown}s' : 'Resend code',
                  style: TextStyle(color: cooldown > 0 ? scheme.onSurfaceVariant : AppColors.accent,
                    fontFamily: 'Inter', fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
