import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/google_account_service.dart';
import '../../shared/widgets/wallpaper_scaffold.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _register = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _finish(AuthResult result) async {
    final user = result.user;
    if (!result.ok || user == null) {
      if (mounted) setState(() => _error = result.error ?? 'Could not sign in.');
      return;
    }
    await ref.read(authNotifierProvider.notifier).signIn(
      userId: user.id,
      displayName: user.name ?? user.email,
      email: user.email,
      photoUrl: user.avatarUrl,
    );
    if (!mounted) return;
    context.go('/profile');
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = _register
        ? await AuthService.instance.register(
            email,
            _password.text,
            _name.text.trim().isEmpty ? null : _name.text.trim(),
          )
        : await AuthService.instance.login(email, _password.text);
    if (mounted) setState(() => _loading = false);
    await _finish(result);
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await GoogleAccountService.instance.signInAndAuthenticate();
    if (mounted) setState(() => _loading = false);
    await _finish(result);
  }

  @override
  Widget build(BuildContext context) {
    return WallpaperScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 42, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShaderMask(
                shaderCallback: AppColors.accentGradient.createShader,
                child: const Text(
                  'OTYA Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'One account for sync, verification and Google Drive backup.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _google,
                  icon: const Icon(Icons.account_circle_rounded),
                  label: const Text('Continue with Google'),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: const [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: TextStyle(color: AppColors.textSecondary)),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ]),
              const SizedBox(height: 18),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Login')),
                  ButtonSegment(value: true, label: Text('Register')),
                ],
                selected: {_register},
                onSelectionChanged: _loading
                    ? null
                    : (value) => setState(() {
                          _register = value.first;
                          _error = null;
                        }),
              ),
              const SizedBox(height: 18),
              if (_register) ...[
                _field(_name, 'Name', Icons.person_outline_rounded),
                const SizedBox(height: 12),
              ],
              _field(_email, 'Email', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (!_register)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => context.push('/auth/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_register ? 'Create OTYA Account' : 'Login'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Google and email/password both connect to your OTYA account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
