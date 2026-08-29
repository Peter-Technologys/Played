import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/consent_service.dart';
import '../../core/services/google_account_service.dart';
import '../../core/services/verification_service.dart';
import '../../shared/widgets/wallpaper_scaffold.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.focusVerification = false});
  final bool focusVerification;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  ConsentState? _consent;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    UserProfile? profile;
    ConsentState? consent;
    try {
      final loggedIn = await AuthService.instance.checkIsLoggedIn();
      if (loggedIn) {
        profile = await AuthService.instance.getProfile();
        if (profile != null) consent = await ConsentService.instance.getConsent();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _consent = consent;
      _loading = false;
    });
    if (widget.focusVerification && profile != null && !profile.isVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyEmail());
    }
  }

  Future<void> _verifyEmail() async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    final delivery = await VerificationService.instance.sendCode();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!delivery.ok) {
      setState(() => _message = delivery.message);
      return;
    }

    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(delivery.message),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 5,
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'A0000',
                labelText: 'Verification code',
              ),
              onChanged: (value) {
                final clean = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                if (clean != value) {
                  controller.value = TextEditingValue(
                    text: clean.substring(0, clean.length.clamp(0, 5)),
                    selection: TextSelection.collapsed(offset: clean.length.clamp(0, 5)),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim().toUpperCase();
              if (RegExp(r'^[A-Z][0-9]{4}$').hasMatch(value)) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null) return;

    setState(() => _busy = true);
    final ok = await AuthService.instance.verifyOtp(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? 'Email verified.' : 'That code is invalid or expired.';
    });
    if (ok) await _refresh();
  }

  Future<void> _connectGoogle() async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final result = await GoogleAccountService.instance.signInAndAuthenticate();
      final user = result.user;
      if (!result.ok || user == null) {
        if (mounted) setState(() => _message = result.error ?? 'Google sign-in failed.');
        return;
      }
      await ref.read(authNotifierProvider.notifier).signIn(
        userId: user.id,
        displayName: user.name ?? user.email,
        email: user.email,
        photoUrl: user.avatarUrl,
      );
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _message = 'Google sign-in could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setMarketing(bool enabled) async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    final ok = await ConsentService.instance.setMarketingConsent(enabled);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? 'Communication preference updated.' : 'Could not update that preference.';
    });
    if (ok) await _refresh();
  }

  Future<void> _acceptCurrentLegal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept current policies?'),
        content: const Text('Review the current Terms and Privacy Policy first. Your acceptance is stored with your OTYA account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('I accept')),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() { _busy = true; _message = null; });
    final ok = await ConsentService.instance.acceptCurrentLegal();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? 'Current policies accepted.' : 'Could not update legal acceptance.';
    });
    if (ok) await _refresh();
  }

  Future<void> _backupDrive() async => _driveAction(
        GoogleAccountService.instance.backupToDrive,
        'Backup saved to your private Google Drive app folder.',
      );

  Future<void> _restoreDrive() async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final count = await GoogleAccountService.instance.restoreFromDrive();
      if (mounted) setState(() => _message = 'Restored $count saved item${count == 1 ? '' : 's'}.');
    } catch (_) {
      if (mounted) setState(() => _message = 'Drive restore could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _driveAction(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } catch (_) {
      if (mounted) setState(() => _message = 'Google Drive action could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await GoogleAccountService.instance.signOut();
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go('/myspace');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete OTYA account?'),
        content: const Text('This permanently deletes the OTYA account and cloud account data. Local media files on this phone are not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete account')),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.deleteAccount();
      await GoogleAccountService.instance.signOut();
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/myspace');
    } catch (_) {
      if (mounted) setState(() { _busy = false; _message = 'Account deletion could not be completed.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return WallpaperScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/myspace'),
        ),
        title: const Text('Account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? _signedOut(context)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 28),
                    children: [
                      _identity(context, profile),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        _notice(context, _message!),
                      ],
                      const SizedBox(height: 22),
                      const _Header('Security'),
                      _Group(children: [
                        if (!profile.isVerified)
                          _ActionTile(
                            icon: Icons.verified_outlined,
                            title: 'Verify email',
                            subtitle: 'Confirm your account email with an OTYA code',
                            onTap: _verifyEmail,
                          ),
                        if (!profile.isVerified) const _Divider(),
                        _ActionTile(
                          icon: Icons.account_circle_rounded,
                          title: GoogleAccountService.instance.hasGoogleSession ? 'Google connected' : 'Connect Google',
                          subtitle: GoogleAccountService.instance.hasGoogleSession
                              ? 'Google is linked to this same OTYA account'
                              : 'Link Google without creating a second OTYA account',
                          onTap: _connectGoogle,
                        ),
                      ]),
                      const SizedBox(height: 22),
                      const _Header('Privacy & communication'),
                      _Group(children: [
                        _ActionTile(
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          subtitle: 'Read the current OTYA Terms',
                          onTap: () => context.push('/webview', extra: const {
                            'url': 'https://petersmartlink.com/terms',
                            'title': 'Terms of Service',
                          }),
                        ),
                        const _Divider(),
                        _ActionTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          subtitle: 'Review how OTYA handles service and account data',
                          onTap: () => context.push('/privacy'),
                        ),
                        if (_consent != null && !_consent!.legalCurrent) ...[
                          const _Divider(),
                          _ActionTile(
                            icon: Icons.fact_check_outlined,
                            title: 'Accept current policies',
                            subtitle: 'Required after a Terms or Privacy version changes',
                            onTap: _acceptCurrentLegal,
                          ),
                        ],
                        if (_consent != null) ...[
                          const _Divider(),
                          SwitchListTile(
                            value: _consent!.marketingConsent,
                            onChanged: _busy ? null : _setMarketing,
                            secondary: const Icon(Icons.campaign_outlined, color: AppColors.accent),
                            title: const Text('OTYA news & promotions', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text('Optional. Security and account messages are always separate.'),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 22),
                      const _Header('Backup'),
                      _Group(children: [
                        _ActionTile(
                          icon: Icons.cloud_upload_rounded,
                          title: 'Back up app data',
                          subtitle: 'Save supported OTYA app data to your private Google Drive app folder',
                          onTap: _backupDrive,
                        ),
                        const _Divider(),
                        _ActionTile(
                          icon: Icons.cloud_download_rounded,
                          title: 'Restore app data',
                          subtitle: 'Restore a compatible OTYA backup from Google Drive',
                          onTap: _restoreDrive,
                        ),
                      ]),
                      const SizedBox(height: 22),
                      const _Header('Account actions'),
                      _Group(children: [
                        _ActionTile(
                          icon: Icons.logout_rounded,
                          title: 'Sign out',
                          subtitle: 'Local playback and local files remain available',
                          onTap: _signOut,
                        ),
                        const _Divider(),
                        _ActionTile(
                          icon: Icons.delete_forever_rounded,
                          title: 'Delete account',
                          subtitle: 'Permanently delete OTYA cloud account data',
                          danger: true,
                          onTap: _deleteAccount,
                        ),
                      ]),
                      if (_busy) ...[
                        const SizedBox(height: 18),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _signedOut(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/icons/play_store_512.png', width: 78, height: 78),
              ),
              const SizedBox(height: 18),
              const Text('Your OTYA account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'An account is optional for local media. Sign in for verification, account security and supported backups.',
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
        ),
      );

  Widget _identity(BuildContext context, UserProfile profile) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
              child: profile.avatarUrl == null
                  ? Text((profile.name ?? profile.email).substring(0, 1).toUpperCase())
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name ?? 'OTYA User', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(profile.email, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(profile.isVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
                          size: 15, color: profile.isVerified ? AppColors.accentGreen : AppColors.warning),
                      const SizedBox(width: 5),
                      Text(profile.isVerified ? 'Verified' : 'Verification needed',
                          style: TextStyle(fontSize: 12, color: profile.isVerified ? AppColors.accentGreen : AppColors.warning)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _notice(BuildContext context, String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Text(text, textAlign: TextAlign.center),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textSecondary)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 58, color: AppColors.borderOf(context));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        leading: Icon(icon, color: danger ? AppColors.error : AppColors.accent),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? AppColors.error : null)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      );
}
