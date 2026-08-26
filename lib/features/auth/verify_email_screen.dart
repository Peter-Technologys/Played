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
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_cooldown > 0 || _loading) return;
    setState(() {
      _error = null;
      _success = null;
      _loading = true;
    });
    await AuthService.instance.sendVerificationOtp();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _success = 'If your account can receive verification mail, a code has been sent.';
      _cooldown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z][0-9]{4}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 5-character code from your email, e.g. A1234.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    final ok = await AuthService.instance.verifyOtp(otp);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified! ✓'),
          backgroundColor: AppColors.surface,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread_outlined,
                  color: AppColors.accent, size: 56),
              const SizedBox(height: 20),
              const Text('Check your email', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary, fontFamily: 'Inter')),
              const SizedBox(height: 8),
              const Text(
                'We sent a 5-character code to your email address.\nEnter it below to verify your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14,
                    fontFamily: 'Inter', height: 1.5),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _otpCtrl,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text,
                maxLength: 5,
                enabled: !_loading,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary,
                    fontFamily: 'Inter', fontSize: 28,
                    fontWeight: FontWeight.w800, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: 'A1234',
                  hintStyle: const TextStyle(color: AppColors.textMuted,
                      fontSize: 28, letterSpacing: 8, fontFamily: 'Inter'),
                  counterText: '', filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error,
                          fontSize: 13, fontFamily: 'Inter')),
                ),
              ],
              if (_success != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Text(_success!, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.success,
                          fontSize: 13, fontFamily: 'Inter')),
                ),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _loading ? null : _verify,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _loading ? null : AppColors.accentGradient,
                    color: _loading ? AppColors.surface : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5,
                                color: AppColors.accent))
                        : const Text('Verify Email',
                            style: TextStyle(color: Colors.black,
                                fontWeight: FontWeight.w800, fontSize: 15,
                                fontFamily: 'Inter')),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: (_cooldown > 0 || _loading) ? null : _sendOtp,
                child: Text(
                  _cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code',
                  style: TextStyle(
                    color: _cooldown > 0 ? AppColors.textMuted : AppColors.accent,
                    fontFamily: 'Inter', fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
