import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/google_account_service.dart';
import '../../shared/widgets/wallpaper_scaffold.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.focusVerification = false});
  final bool focusVerification;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final loggedIn = await AuthService.instance.checkIsLoggedIn();
    UserProfile? profile;
    if (loggedIn) profile = await AuthService.instance.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
    if (widget.focusVerification && profile != null && !profile.isVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyEmail());
    }
  }

  Future<void> _verifyEmail() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final sendResult = await AuthService.instance.sendVerificationOtpDetailed();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!sendResult.ok) {
      setState(() => _message = sendResult.message);
      return;
    }

    final controllers = List.generate(5, (_) => TextEditingController());
    final focusNodes = List.generate(5, (_) => FocusNode());
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code sent to ${_profile?.email ?? AuthService.instance.userEmail ?? 'your email'}.',
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                5,
                (index) => SizedBox(
                  width: 48,
                  child: TextField(
                    controller: controllers[index],
                    focusNode: focusNodes[index],
                    maxLength: 1,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType:
                        index == 0 ? TextInputType.text : TextInputType.number,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: index == 0 ? 'A' : '0',
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length > 1) {
                        controllers[index].text =
                            value.characters.last.toUpperCase();
                        controllers[index].selection =
                            const TextSelection.collapsed(offset: 1);
                      }
                      if (value.isNotEmpty && index < 4) {
                        focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controllers
                  .map((c) => c.text.trim().toUpperCase())
                  .join();
              if (RegExp(r'^[A-Z][0-9]{4}$').hasMatch(value)) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    for (final c in controllers) {
      c.dispose();
    }
    for (final n in focusNodes) {
      n.dispose();
    }
    if (code == null || code.isEmpty) return;
    setState(() => _busy = true);
    final ok = await AuthService.instance.verifyOtp(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok
          ? 'Email verified.'
          : 'Invalid or expired verification code. Request a new code and try again.';
    });
    if (ok) await _refresh();
  }

  Future<void> _connectGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await GoogleAccountService.instance.signInAndAuthenticate();
    if (!mounted) return;
    setState(() => _busy = false);
    final user = result.user;
    if (!result.ok || user == null) {
      setState(() => _message = result.error ?? 'Google Sign-In failed.');
      return;
    }
    await ref.read(authNotifierProvider.notifier).signIn(
      userId: user.id,
      displayName: user.name ?? user.email,
      email: user.email,
      photoUrl: user.avatarUrl,
    );
    await _refresh();
  }

  Future<void> _backupDrive() async => _runDrive(
        () => GoogleAccountService.instance.backupToDrive(),
        'Backup saved to Google Drive.',
      );

  Future<void> _restoreDrive() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final count = await GoogleAccountService.instance.restoreFromDrive();
      if (mounted) {
        setState(
          () => _message =
              'Restored $count item${count == 1 ? '' : 's'} from Google Drive.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Google Drive restore could not be completed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runDrive(
    Future<void> Function() action,
    String success,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Google Drive action could not be completed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await GoogleAccountService.instance.signOut();
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go('/myspace');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete OTYA account?'),
        content: const Text(
          'This permanently deletes the OTYA account and its cloud data. Local media files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await AuthService.instance.deleteAccount();
    await GoogleAccountService.instance.signOut();
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go('/myspace');
  }

  void _go(String route) => context.go(route);

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return WallpaperScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/myspace'),
        ),
        title: const Text('Account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? _signedOut()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                  children: [
                    _identity(profile),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      _notice(_message!),
                    ],
                    const SizedBox(height: 20),
                    const _Header('Account security'),
                    if (!profile.isVerified)
                      _tile(
                        Icons.verified_outlined,
                        'Verify email',
                        'Confirm your OTYA account email',
                        _verifyEmail,
                      ),
                    _tile(
                      Icons.account_circle_rounded,
                      GoogleAccountService.instance.hasGoogleSession
                          ? 'Google connected'
                          : 'Connect Google',
                      GoogleAccountService.instance.hasGoogleSession
                          ? 'Google identity is connected to this OTYA account'
                          : 'Use Google with this same OTYA account',
                      _connectGoogle,
                    ),
                    const SizedBox(height: 20),
                    const _Header('Backup & sync'),
                    _tile(
                      Icons.cloud_upload_rounded,
                      'Back up to Google Drive',
                      'Private app backup',
                      _backupDrive,
                    ),
                    _tile(
                      Icons.cloud_download_rounded,
                      'Restore from Google Drive',
                      'Restore your OTYA backup',
                      _restoreDrive,
                    ),
                    const SizedBox(height: 20),
                    const _Header('Account actions'),
                    _tile(
                      Icons.logout_rounded,
                      'Sign out',
                      'Keep local media on this device',
                      _signOut,
                    ),
                    _tile(
                      Icons.delete_forever_rounded,
                      'Delete account',
                      'Permanently delete OTYA cloud account data',
                      _deleteAccount,
                      danger: true,
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          if (index == 0) {
            _go('/');
          } else if (index == 1) {
            _go('/music');
          } else {
            _go('/myspace');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline_rounded),
            label: 'Watch',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_rounded),
            label: 'Listen',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Hub',
          ),
        ],
      ),
    );
  }

  Widget _signedOut() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 72,
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your OTYA account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in once for verification, sync, Google connection and backup.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/auth'),
                child: const Text('Sign in or create account'),
              ),
            ),
          ],
        ),
      );

  Widget _identity(UserProfile p) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage:
                  p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
              child: p.avatarUrl == null
                  ? Text((p.name ?? p.email).substring(0, 1).toUpperCase())
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name ?? 'OTYA User',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    p.email,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.isVerified ? 'Email verified' : 'Email not verified',
                    style: TextStyle(
                      color: p.isVerified
                          ? AppColors.accentGreen
                          : AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _notice(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text, textAlign: TextAlign.center),
      );

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool danger = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ListTile(
          onTap: _busy ? null : onTap,
          tileColor: AppColors.surface.withValues(alpha: .86),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          leading: Icon(
            icon,
            color: danger ? AppColors.error : AppColors.accent,
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}
