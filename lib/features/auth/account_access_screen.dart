import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/consent_service.dart';
import '../../core/services/fcm_service.dart';
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
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _marketingConsent = false;
  bool _twoFactorRequired = false;
  bool _useRecoveryCode = false;
  String? _error;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _twoFactor = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _twoFactor.dispose();
    super.dispose();
  }

  Future<void> _finish(AuthResult result, {bool saveMarketingConsent = false}) async {
    final user = result.user;
    if (!result.ok || user == null) {
      if (mounted) {
        final message = result.error ?? 'Could not sign in.';
        setState(() {
          _error = message;
          if (message.contains('Terms of Service') ||
              message.contains('Privacy Policy') ||
              message.contains('create your OTYA account') ||
              message.contains('create your Otya account')) {
            _register = true;
          }
        });
      }
      return;
    }
    await ref.read(authNotifierProvider.notifier).signIn(
      userId: user.id,
      displayName: user.name ?? user.email ?? 'Otya user',
      email: user.email,
      photoUrl: user.avatarUrl,
    );
    await FcmService.instance.syncRegistration();
    if (saveMarketingConsent) {
      await ConsentService.instance.setMarketingConsent(_marketingConsent);
    }
    if (!mounted) return;
    context.go('/profile');
  }

  bool _validateRegistrationConsent() {
    if (!_termsAccepted || !_privacyAccepted) {
      setState(() => _error =
          'Accept the Terms of Service and Privacy Policy to create your Otya account.');
      return false;
    }
    return true;
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
    if (_register && !_validateRegistrationConsent()) return;
    if (_twoFactorRequired && _twoFactor.text.trim().isEmpty) {
      setState(() => _error = _useRecoveryCode
          ? 'Enter one of your Otya recovery codes.'
          : 'Enter the 6-digit code from your authenticator app.');
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
            termsAccepted: _termsAccepted,
            privacyAccepted: _privacyAccepted,
            marketingConsent: _marketingConsent,
          )
        : await AuthService.instance.login(
            email,
            _password.text,
            totpCode: _twoFactorRequired && !_useRecoveryCode
                ? _twoFactor.text.trim()
                : null,
            recoveryCode: _twoFactorRequired && _useRecoveryCode
                ? _twoFactor.text.trim()
                : null,
          );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!_register && (result.twoFactorRequired || result.twoFactorInvalid)) {
      setState(() {
        _twoFactorRequired = true;
        _error = result.error ?? 'Two-step verification is required.';
        if (result.twoFactorInvalid) _twoFactor.clear();
      });
      return;
    }

    await _finish(result, saveMarketingConsent: _register);
  }

  Future<void> _google() async {
    if (_register && !_validateRegistrationConsent()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await GoogleAccountService.instance.signInAndAuthenticate(
      termsAccepted: _register && _termsAccepted,
      privacyAccepted: _register && _privacyAccepted,
      marketingConsent: _register && _marketingConsent,
    );
    if (mounted) setState(() => _loading = false);
    await _finish(result, saveMarketingConsent: _register);
  }

  void _switchMode(bool register) {
    setState(() {
      _register = register;
      _error = null;
      _twoFactorRequired = false;
      _useRecoveryCode = false;
      _twoFactor.clear();
    });
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
                  'Otya Account',
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
              Text(
                _twoFactorRequired
                    ? 'Confirm this sign-in with your Otya two-step verification.'
                    : 'One secure account for verification, recovery, supported backup services and saved Next conversations.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),
              if (!_twoFactorRequired) ...[
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _google,
                    icon: const Icon(Icons.account_circle_rounded),
                    label: const Text('Continue with Google'),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(children: [
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
                      : (value) => _switchMode(value.first),
                ),
                const SizedBox(height: 18),
              ],
              if (_register) ...[
                _field(_name, 'Name', Icons.person_outline_rounded),
                const SizedBox(height: 12),
              ],
              _field(
                _email,
                'Email',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !_twoFactorRequired,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscure,
                enabled: !_twoFactorRequired,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: _twoFactorRequired
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (_twoFactorRequired) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _twoFactor,
                  autofocus: true,
                  keyboardType: _useRecoveryCode
                      ? TextInputType.text
                      : TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: _useRecoveryCode ? 14 : 6,
                  decoration: InputDecoration(
                    labelText: _useRecoveryCode
                        ? 'Recovery code'
                        : 'Authenticator code',
                    helperText: _useRecoveryCode
                        ? 'Use one unused recovery code from your Otya account.'
                        : 'Enter the 6-digit code from your authenticator app.',
                    prefixIcon: Icon(_useRecoveryCode
                        ? Icons.vpn_key_outlined
                        : Icons.security_rounded),
                    counterText: '',
                  ),
                  onSubmitted: (_) {
                    if (!_loading) _submit();
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _useRecoveryCode = !_useRecoveryCode;
                              _twoFactor.clear();
                              _error = null;
                            }),
                    child: Text(_useRecoveryCode
                        ? 'Use authenticator code instead'
                        : 'Use a recovery code instead'),
                  ),
                ),
              ],
              if (!_register && !_twoFactorRequired)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : () => context.push('/auth/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (_register) ...[
                const SizedBox(height: 14),
                _consentRow(
                  value: _termsAccepted,
                  onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                  label: 'I accept the Terms of Service',
                  onOpen: () => context.push('/webview', extra: {
                    'url': 'https://petersmartlink.com/terms',
                    'title': 'Terms of Service',
                  }),
                ),
                _consentRow(
                  value: _privacyAccepted,
                  onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
                  label: 'I accept the Privacy Policy',
                  onOpen: () => context.push('/privacy'),
                ),
                CheckboxListTile(
                  value: _marketingConsent,
                  onChanged: (v) => setState(() => _marketingConsent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Send me Otya news, product announcements and promotions'),
                  subtitle: const Text(
                    'Optional. You can turn this off later. Security, account and legal notices are still sent when needed.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
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
                      : Text(_twoFactorRequired
                          ? 'Verify and sign in'
                          : (_register ? 'Create Otya Account' : 'Login')),
                ),
              ),
              if (_twoFactorRequired) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _twoFactorRequired = false;
                            _twoFactor.clear();
                            _error = null;
                          }),
                  child: const Text('Use another account'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _twoFactorRequired
                    ? 'Otya never asks you to share authenticator or recovery codes outside the official sign-in flow.'
                    : 'Google and email/password both connect to the same Otya account. Local playback does not require sign-in.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _consentRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required VoidCallback onOpen,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(
          child: TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            child: Text(label),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
