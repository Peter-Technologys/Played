// lib/features/auth/auth_screen.dart
//
// Login / Register screen.
// AMOLED dark theme — violet #8B5CF6 + cyan #00E5FF matching AppColors.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Logo / title
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.accentGradient.createShader(bounds),
              child: const Text(
                'OTYA Player',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to sync your music across devices',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 32),
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Login'),
                  Tab(text: 'Register'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _LoginTab(onSuccess: _onSuccess),
                  _RegisterTab(onSuccess: _onSuccess),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSuccess(UserProfile user) {
    // Update legacy auth provider so existing screens still work
    ref.read(authNotifierProvider.notifier).signIn(
      userId:      user.id,
      displayName: user.name ?? user.email,
      email:       user.email,
      photoUrl:    user.avatarUrl,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user.name ?? user.email}!'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/');
    }
  }
}

// ── Login Tab ─────────────────────────────────────────────────────────────────

class _LoginTab extends StatefulWidget {
  final void Function(UserProfile) onSuccess;
  const _LoginTab({required this.onSuccess});

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading       = false;
  String? _error;
  bool _obscure       = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.ok && result.user != null) {
      widget.onSuccess(result.user!);
    } else {
      setState(() => _error = result.error ?? 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthField(
            controller: _emailCtrl,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _passwordCtrl,
            label: 'Password',
            obscure: _obscure,
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/auth/forgot-password'),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 16),
          _GradientButton(
            label: 'Login',
            loading: _loading,
            onPressed: _login,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Register Tab ──────────────────────────────────────────────────────────────

class _RegisterTab extends StatefulWidget {
  final void Function(UserProfile) onSuccess;
  const _RegisterTab({required this.onSuccess});

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading       = false;
  String? _error;
  bool _obscure       = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_passwordCtrl.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.register(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
      _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.ok && result.user != null) {
      widget.onSuccess(result.user!);
      // Navigate to verify email if not verified
      if (!(result.user!.isVerified)) {
        context.push('/auth/verify-email');
      }
    } else {
      setState(() => _error = result.error ?? 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthField(
            controller: _nameCtrl,
            label: 'Name (optional)',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _emailCtrl,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _passwordCtrl,
            label: 'Password (min 8 chars)',
            obscure: _obscure,
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          _GradientButton(
            label: 'Create Account',
            loading: _loading,
            onPressed: _register,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData icon;
  final Widget? suffix;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      obscureText:  obscure,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'Inter',
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText:     label,
        labelStyle:    const TextStyle(color: AppColors.textSecondary, fontFamily: 'Inter'),
        prefixIcon:    Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon:    suffix,
        filled:        true,
        fillColor:     AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: loading ? null : AppColors.accentGradient,
          color:    loading ? AppColors.surface : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.accent,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                ),
        ),
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
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
