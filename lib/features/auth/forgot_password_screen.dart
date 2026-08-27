import 'dart:async';

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
  DateTime? _resendAvailableAt;
  Timer? _cooldownTimer;
  int _requestGeneration = 0;

  int get _cooldown {
    final deadline = _resendAvailableAt;
    if (deadline == null) return 0;
    return (deadline.difference(DateTime.now()).inSeconds + 1).clamp(0, 60);
  }

  @override
  void dispose() {
    _requestGeneration++;
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_cooldown <= 0) {
        timer.cancel();
        _cooldownTimer = null;
        setState(() => _resendAvailableAt = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_loading || _cooldown > 0) return;
    final email = (_step == 1 ? _emailCtrl.text : _email).trim().toLowerCase();
    if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    final generation = ++_requestGeneration;
    setState(() { _loading = true; _error = null; });
    bool sent = false;
    try {
      sent = await AuthService.instance.forgotPassword(email)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      sent = false;
    }
    if (!mounted || generation != _requestGeneration) return;
    setState(() => _loading = false);
    if (!sent) {
      setState(() => _error = 'We could not contact the password-reset service. Check your connection and try again.');
      return;
    }
    _startCooldown();
    setState(() {
      _email = email;
      _step = 2;
    });
  }

  Future<void> _resetPassword() async {
    if (_loading) return;
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
    if (newPass.length > 128) {
      setState(() => _error = 'Password is too long');
      return;
    }

    final generation = ++_requestGeneration;
    setState(() { _loading = true; _error = null; });
    bool ok = false;
    try {
      ok = await AuthService.instance.resetPassword(_email, otp, newPass)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      ok = false;
    }
    if (!mounted || generation != _requestGeneration) return;
    setState(() => _loading = false);
    if (ok) {
      _newPassCtrl.clear();
      _otpCtrl.clear();
      setState(() => _step = 3);
    } else {
      setState(() => _error = 'Invalid or expired code, or the service is unavailable. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onSurfaceVariant, size: 20),
          onPressed: _loading ? null : () => context.pop(),
        ),
        title: Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface, fontFamily: 'Inter')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: _step == 1 ? _buildStep1(scheme) : _step == 2 ? _buildStep2(scheme) : _buildStep3(scheme),
        ),
      ),
    );
  }

  Widget _buildStep1(ColorScheme scheme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Enter your email address and we’ll send you a reset code.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, fontFamily: 'Inter', height: 1.5)),
      const SizedBox(height: 24),
      _Field(controller: _emailCtrl, label: 'Email address', keyboardType: TextInputType.emailAddress, icon: Icons.email_outlined, enabled: !_loading, autofillHints: const [AutofillHints.email]),
      if (_error != null) ...[const SizedBox(height: 12), _ErrorBanner(message: _error!)],
      const SizedBox(height: 20),
      _GradientButton(label: 'Send Reset Code', loading: _loading, onPressed: _sendOtp),
    ],
  );

  Widget _buildStep2(ColorScheme scheme) {
    final cooldown = _cooldown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('If the account can receive reset mail, enter the code sent to $_email and choose a new password.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, fontFamily: 'Inter', height: 1.5)),
        const SizedBox(height: 24),
        _Field(controller: _otpCtrl, label: 'Reset code (e.g. A1234)', icon: Icons.key_rounded, textCapitalization: TextCapitalization.characters, maxLength: 5, enabled: !_loading, autofillHints: const [AutofillHints.oneTimeCode]),
        const SizedBox(height: 12),
        _Field(controller: _newPassCtrl, label: 'New password (min 8 chars)', icon: Icons.lock_outline_rounded, obscure: _obscure, enabled: !_loading, autofillHints: const [AutofillHints.newPassword], suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: scheme.onSurfaceVariant, size: 20), onPressed: _loading ? null : () => setState(() => _obscure = !_obscure))),
        if (_error != null) ...[const SizedBox(height: 12), _ErrorBanner(message: _error!)],
        const SizedBox(height: 20),
        _GradientButton(label: 'Reset Password', loading: _loading, onPressed: _resetPassword),
        const SizedBox(height: 12),
        TextButton(onPressed: (_loading || cooldown > 0) ? null : _sendOtp, child: Text(cooldown > 0 ? 'Resend code in ${cooldown}s' : 'Resend code', style: TextStyle(color: cooldown > 0 ? scheme.onSurfaceVariant : AppColors.accent, fontFamily: 'Inter'))),
      ],
    );
  }

  Widget _buildStep3(ColorScheme scheme) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 48),
      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
      const SizedBox(height: 20),
      Text('Password reset!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface, fontFamily: 'Inter')),
      const SizedBox(height: 8),
      Text('Your password has been updated. You can now log in with your new password.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, fontFamily: 'Inter', height: 1.5)),
      const SizedBox(height: 32),
      _GradientButton(label: 'Back to Login', loading: false, onPressed: () => context.go('/auth')),
    ],
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final IconData icon;
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  const _Field({required this.controller, required this.label, required this.icon, this.obscure = false, this.enabled = true, this.keyboardType, this.suffix, this.textCapitalization = TextCapitalization.none, this.maxLength, this.autofillHints});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller, enabled: enabled, obscureText: obscure,
      keyboardType: keyboardType, textCapitalization: textCapitalization,
      maxLength: maxLength, autofillHints: autofillHints,
      autocorrect: false, enableSuggestions: !obscure,
      style: TextStyle(color: scheme.onSurface, fontFamily: 'Inter', fontSize: 15),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontFamily: 'Inter'),
        prefixIcon: Icon(icon, color: scheme.onSurfaceVariant, size: 20), suffixIcon: suffix,
        counterText: '', filled: true, fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
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
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    child: loading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent))
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, fontFamily: 'Inter')),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
    child: Row(children: [const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13, fontFamily: 'Inter')))]),
  );
}
