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
import '../../shared/widgets/otya_logo.dart';
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
  bool _verificationPromptShown = false;

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
        if (profile != null) {
          consent = await ConsentService.instance.getConsent();
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _consent = consent;
      _loading = false;
    });

    if (widget.focusVerification &&
        !_verificationPromptShown &&
        profile != null &&
        profile.email?.trim().isNotEmpty == true &&
        !profile.isVerified) {
      _verificationPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verifyEmail();
      });
    }
  }

  void _setBusy(bool value, {String? message}) {
    if (!mounted) return;
    setState(() {
      _busy = value;
      if (message != null) _message = message;
    });
  }

  Future<void> _verifyEmail() async {
    if (_busy) return;
    final email = _profile?.email?.trim();
    if (email == null || email.isEmpty) {
      if (mounted) {
        setState(() => _message =
            'This account does not have a primary email yet. Add one from Otya Space before requesting email verification.');
      }
      return;
    }

    _setBusy(true);
    setState(() => _message = null);

    final delivery = await VerificationService.instance.sendCode();
    if (!mounted) return;
    _setBusy(false);
    if (!delivery.ok) {
      setState(() => _message = delivery.message);
      return;
    }

    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const OtyaLogo(iconOnly: true, fontSize: 48),
        title: const Text('Verify your email'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(delivery.message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 5,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'A0000',
                  labelText: 'Otya verification code',
                ),
                onChanged: (value) {
                  final clean = value
                      .toUpperCase()
                      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
                  final trimmed = clean.substring(0, clean.length.clamp(0, 5));
                  if (trimmed != value) {
                    controller.value = TextEditingValue(
                      text: trimmed,
                      selection: TextSelection.collapsed(offset: trimmed.length),
                    );
                  }
                },
                onSubmitted: (value) {
                  final clean = value.trim().toUpperCase();
                  if (RegExp(r'^[A-Z][0-9]{4}$').hasMatch(clean)) {
                    Navigator.pop(dialogContext, clean);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
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
    if (code == null || !mounted) return;

    _setBusy(true);
    final ok = await AuthService.instance.verifyOtp(code);
    if (!mounted) return;
    _setBusy(false);
    setState(() {
      _message = ok ? 'Email verified.' : 'That code is invalid or expired.';
    });
    if (ok) await _refresh();
  }

  Future<void> _connectGoogle() async {
    if (_busy) return;
    _setBusy(true);
    setState(() => _message = null);
    try {
      final result = await GoogleAccountService.instance.signInAndAuthenticate();
      final user = result.user;
      if (!result.ok || user == null) {
        if (mounted) {
          setState(() => _message = result.error ?? 'Google sign-in failed.');
        }
        return;
      }
      await ref.read(authNotifierProvider.notifier).signIn(
            userId: user.id,
            displayName: user.name ?? user.email ?? 'Otya user',
            email: user.email,
            photoUrl: user.avatarUrl,
          );
      await _refresh();
      if (mounted) setState(() => _message = 'Google account connected.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Google sign-in could not be completed.');
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _setMarketing(bool enabled) async {
    if (_busy) return;
    _setBusy(true);
    setState(() => _message = null);
    final ok = await ConsentService.instance.setMarketingConsent(enabled);
    if (!mounted) return;
    _setBusy(false);
    setState(() {
      _message = ok
          ? 'Communication preference updated.'
          : 'Could not update that preference.';
    });
    if (ok) await _refresh();
  }

  Future<void> _acceptCurrentLegal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept current policies?'),
        content: const Text(
          'Review the current Terms and Privacy Policy first. Your acceptance is stored with your Otya account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I accept'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;

    _setBusy(true);
    setState(() => _message = null);
    final ok = await ConsentService.instance.acceptCurrentLegal();
    if (!mounted) return;
    _setBusy(false);
    setState(() {
      _message = ok
          ? 'Current policies accepted.'
          : 'Could not update legal acceptance.';
    });
    if (ok) await _refresh();
  }

  Future<void> _backupPlaylists() async {
    await _driveAction(
      GoogleAccountService.instance.backupToDrive,
      'Playlists backed up to your private Google Drive app folder.',
    );
  }

  Future<void> _restorePlaylists() async {
    if (_busy) return;
    _setBusy(true);
    setState(() => _message = null);
    try {
      final count = await GoogleAccountService.instance.restoreFromDrive();
      if (mounted) {
        setState(() {
          _message = count == 0
              ? 'No compatible playlist backup was found.'
              : 'Restored $count playlist${count == 1 ? '' : 's'}.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Playlist restore could not be completed.');
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _deletePlaylistBackup() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete playlist backup?'),
        content: const Text(
          'This removes the Otya recovery snapshot from your private Google Drive app folder. It does not delete playlists already stored on this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete backup'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _driveAction(
      GoogleAccountService.instance.deleteDriveBackup,
      'Playlist backup deleted from Google Drive.',
    );
  }

  Future<void> _driveAction(
    Future<void> Function() action,
    String success,
  ) async {
    if (_busy) return;
    _setBusy(true);
    setState(() => _message = null);
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Google Drive action could not be completed. Check your connection and permissions.';
        });
      }
    } finally {
      _setBusy(false);
    }
  }

  void _openAccountCenter(String section, String title) {
    context.push(
      '/webview',
      extra: {
        'url': 'https://space.petersmartlink.com/account#$section',
        'title': title,
      },
    );
  }

  Future<void> _signOut() async {
    if (_busy) return;
    _setBusy(true);
    await GoogleAccountService.instance.signOut();
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go('/myspace');
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Otya account?'),
        content: const Text(
          'This permanently deletes your Otya cloud account and account data. Media and Private files stored locally on this phone are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _setBusy(true);
    try {
      await AuthService.instance.deleteAccount();
      await GoogleAccountService.instance.signOut();
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) context.go('/myspace');
    } catch (_) {
      _setBusy(false, message: 'Account deletion could not be completed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return WallpaperScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/myspace'),
        ),
        title: const Text('Account'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? _SignedOutAccount(onSignIn: () => context.push('/auth'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      final horizontal = wide ? 32.0 : 16.0;
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          8,
                          horizontal,
                          MediaQuery.paddingOf(context).bottom + 32,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 920),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _IdentityCard(profile: profile),
                                  if (_message != null) ...[
                                    const SizedBox(height: 12),
                                    _Notice(text: _message!),
                                  ],
                                  if (_busy) ...[
                                    const SizedBox(height: 10),
                                    const LinearProgressIndicator(minHeight: 2),
                                  ],
                                  const SizedBox(height: 24),
                                  if (wide)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _securityAndPrivacy(profile)),
                                        const SizedBox(width: 18),
                                        Expanded(child: _backupAndAccount()),
                                      ],
                                    )
                                  else ...[
                                    _securityAndPrivacy(profile),
                                    const SizedBox(height: 18),
                                    _backupAndAccount(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _securityAndPrivacy(UserProfile profile) {
    final hasEmail = profile.email?.trim().isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Security'),
        _CardGroup(
          children: [
            if (hasEmail && !profile.isVerified) ...[
              _AccountTile(
                icon: Icons.verified_outlined,
                title: 'Verify email',
                subtitle: 'Confirm your account email with an Otya code',
                onTap: _verifyEmail,
              ),
              const _InsetDivider(),
            ],
            if (!hasEmail) ...[
              _AccountTile(
                icon: Icons.alternate_email_rounded,
                title: 'Primary email',
                subtitle: 'Add an email from Otya Space for email recovery and verification',
                onTap: () => _openAccountCenter('sign-in-methods', 'Sign-in methods'),
              ),
              const _InsetDivider(),
            ],
            _AccountTile(
              icon: Icons.account_circle_rounded,
              title: GoogleAccountService.instance.hasGoogleSession
                  ? 'Google connected'
                  : 'Connect Google',
              subtitle: GoogleAccountService.instance.hasGoogleSession
                  ? 'Google is linked to this Otya account'
                  : 'Use Google as another secure way to access this same Otya account',
              onTap: _connectGoogle,
            ),
            const _InsetDivider(),
            _AccountTile(
              icon: Icons.phonelink_lock_rounded,
              title: 'Two-step verification',
              subtitle: 'Manage authenticator and recovery codes',
              onTap: () => _openAccountCenter('security', 'Account security'),
            ),
            const _InsetDivider(),
            _AccountTile(
              icon: Icons.devices_rounded,
              title: 'Devices & sessions',
              subtitle: 'Review sessions and sign out devices you no longer use',
              onTap: () => _openAccountCenter('sessions', 'Devices & sessions'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Privacy & communication'),
        _CardGroup(
          children: [
            _AccountTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Read the current Otya Terms',
              onTap: () => context.push(
                '/webview',
                extra: const {
                  'url': 'https://petersmartlink.com/terms',
                  'title': 'Terms of Service',
                },
              ),
            ),
            const _InsetDivider(),
            _AccountTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Review how Otya handles service and account data',
              onTap: () => context.push('/privacy'),
            ),
            if (_consent != null && !_consent!.legalCurrent) ...[
              const _InsetDivider(),
              _AccountTile(
                icon: Icons.fact_check_outlined,
                title: 'Accept current policies',
                subtitle: 'Required after a Terms or Privacy version changes',
                onTap: _acceptCurrentLegal,
              ),
            ],
            if (_consent != null) ...[
              const _InsetDivider(),
              SwitchListTile.adaptive(
                value: _consent!.marketingConsent,
                onChanged: _busy ? null : _setMarketing,
                secondary: const Icon(
                  Icons.campaign_outlined,
                  color: AppColors.accent,
                ),
                title: const Text(
                  'Otya news & promotions',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Optional. Security and account messages remain separate.',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _backupAndAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Playlist backup'),
        _CardGroup(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'Otya currently backs up playlist names and saved media references. Media files, Private files and app settings stay on this device.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            _AccountTile(
              icon: Icons.cloud_upload_rounded,
              title: 'Back up playlists',
              subtitle: 'Save a recovery snapshot to your private Google Drive app folder',
              onTap: _backupPlaylists,
            ),
            const _InsetDivider(),
            _AccountTile(
              icon: Icons.cloud_download_rounded,
              title: 'Restore playlists',
              subtitle: 'Restore playlists from a compatible Otya recovery snapshot',
              onTap: _restorePlaylists,
            ),
            const _InsetDivider(),
            _AccountTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Drive backup',
              subtitle: 'Remove only the Otya recovery snapshot from Google Drive',
              onTap: _deletePlaylistBackup,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Account actions'),
        _CardGroup(
          children: [
            _AccountTile(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: 'Local playback and local files remain available',
              onTap: _signOut,
            ),
            const _InsetDivider(),
            _AccountTile(
              icon: Icons.delete_forever_rounded,
              title: 'Delete account',
              subtitle: 'Permanently delete Otya cloud account data',
              danger: true,
              onTap: _deleteAccount,
            ),
          ],
        ),
      ],
    );
  }
}

class _SignedOutAccount extends StatelessWidget {
  const _SignedOutAccount({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OtyaLogo(iconOnly: true, fontSize: 78),
              const SizedBox(height: 20),
              Text(
                'Your Otya account',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'You do not need an account to play local media. Sign in for account security, email verification and optional playlist backup.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in or create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final initialSource = (profile.name ?? profile.email ?? 'Otya').trim();
    final initial = initialSource.isEmpty
        ? 'O'
        : initialSource.characters.first.toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    final hasEmail = profile.email?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name ?? profile.email ?? 'Otya user',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email ?? 'No primary email added',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: !hasEmail
                      ? 'No primary email'
                      : profile.isVerified
                          ? 'Email verified'
                          : 'Email verification needed',
                  child: Row(
                    children: [
                      Icon(
                        !hasEmail
                            ? Icons.alternate_email_rounded
                            : profile.isVerified
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                        size: 16,
                        color: !hasEmail
                            ? scheme.onSurfaceVariant
                            : profile.isVerified
                                ? AppColors.accentGreen
                                : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          !hasEmail
                              ? 'Provider-only account'
                              : profile.isVerified
                                  ? 'Verified'
                                  : 'Verification needed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !hasEmail
                                ? scheme.onSurfaceVariant
                                : profile.isVerified
                                    ? AppColors.accentGreen
                                    : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(children: children),
      );
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 58,
        color: AppColors.borderOf(context),
      );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Theme.of(context).colorScheme.error : AppColors.accent;
    return ListTile(
      minTileHeight: 60,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: danger ? color : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
