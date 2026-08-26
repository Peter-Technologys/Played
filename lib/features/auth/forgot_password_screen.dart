// lib/features/auth/forgot_password_screen.dart
//
// Step 1: Enter email → sends OTP
// Step 2: Enter OTP (A1234 format) + new password
// Step 3: Success → navigate back to login

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1;
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String _email = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await AuthService.instance.forgotPassword(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _email = email;
      _step = 2;
    });
  }

  Future<void> _resetPassword() async {
    final otp = _otpCtrl.text.trim().toUpperCase();
    final newPass = _newPassCtrl.text;
    if (!RegExp(r'^[A-Z][0-9]{4}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 5-character reset code, e.g. A1234');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await AuthService.instance.resetPassword(_email, otp, newPass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      setState(() => _step = 3);
    } else {
      setState(() => _error = 'Invalid or expired OTP. Please try again.');
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Inter')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _step == 1 ? _buildStep1() : _step == 2 ? _buildStep2() : _buildStep3(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enter your email address and we\'ll send you a reset code.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Inter', height: 1.5)),
        const SizedBox(height: 24),
        _Field(controller: _emailCtrl, label: 'Email address', keyboardType: TextInputType.emailAddress, icon: Icons.email_outlined),
        if (_error != null) ...[const SizedBox(height: 12), _ErrorBanner(message: _error!)],
        const SizedBox(height: 20),
        _GradientButton(label: 'Send Reset Code', loading: _loading, onPressed: _sendOtp),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('We sent a code to $_email. Enter it below along with your new password.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Inter', height: 1.5)),
        const SizedBox(height: 24),
        _Field(controller: _otpCtrl, label: 'Reset code (e.g. A1234)', icon: Icons.key_rounded, textCapitalization: TextCapitalization.characters, maxLength: 5),
        const SizedBox(height: 12),
        _Field(controller: _newPassCtrl, label: 'New password (min 8 chars)', icon: Icons.lock_outline_rounded, obscure: _obscure, suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textSecondary, size: 20), onPressed: () => setState(() => _obscure = !_obscure))),
        if (_error != null) ...[const SizedBox(height: 12), _ErrorBanner(message: _error!)],
        const SizedBox(height: 20),
        _GradientButton(label: 'Reset Password', loading: _loading, onPressed: _resetPassword),
        const SizedBox(height: 12),
        TextButton(onPressed: _loading ? null : _sendOtp, child: const Text('Resend code', style: TextStyle(color: AppColors.accent, fontFamily: 'Inter'))),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
        const SizedBox(height: 20),
        const Text('Password reset!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Inter')),
        const SizedBox(height: 8),
        const Text('Your password has been updated. You can now log in with your new password.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Inter', height: 1.5)),
        const SizedBox(height: 32),
        _GradientButton(label: 'Back to Login', loading: false, onPressed: () => context.go('/auth')),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData icon;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  const _Field({required this.controller, required this.label, required this.icon, this.obscure = false, this.keyboardType, this.suffix, this.textCapitalization = TextCapitalization.none, this.maxLength});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter', fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Inter'),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffix,
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const _GradientButton({required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(gradient: loading ? null : AppColors.accentGradient, color: loading ? AppColors.surface : null, borderRadius: BorderRadius.circular(16)),
        child: Center(child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)) : Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15, fontFamily: 'Inter'))),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
      child: Row(children: [const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13, fontFamily: 'Inter')))]),
    );
  }
}
