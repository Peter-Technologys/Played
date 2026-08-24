import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/cloudflare_service.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/auth_service.dart';



// ─────────────────────────────────────────────────────────────────────────────
// Profile & Settings Screen
//   Account → Privacy & Security → Backup & Sync → App Updates → About
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGoogle    = ref.watch(isSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final photoUrl    = ref.watch(photoUrlProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Account & Profile',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [

          // ── 1. ACCOUNT ────────────────────────────────────────────────
          const _SectionHeader(label: 'Account'),
          const SizedBox(height: 12),
          if (isGoogle) ...[  
            _AccountCard(
              photoUrl: photoUrl,
              displayName: displayName,
              onSignOut: () => _confirmSignOut(context, ref),
            ).animate().fadeIn(duration: 300.ms),
          ] else ...[  
            _GoogleSignInButton(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Google Sign-In coming soon'),
                    backgroundColor: AppColors.surface,
                  ),
                );
              },
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            const Text(
              'Sign in with Google to back up your playlists and play history to your account.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ],

          const SizedBox(height: 20),

          // ── 1b. OTYA ACCOUNT ─────────────────────────────────────────
          const _SectionHeader(label: 'OTYA Account'),
          const SizedBox(height: 8),
          _OtyaAccountSection(),

          const SizedBox(height: 20),

                    // ── 2. BACKUP & SYNC ──────────────────────────────────────────
          const _SectionHeader(label: 'Backup & Sync'),
          const SizedBox(height: 8),
          if (!isGoogle)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sign in with Google above to enable cloud backup.',
                        style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _TappableTile(
            icon: Icons.cloud_upload_rounded,
            label: 'Back Up to Cloud',
            subtitle: isGoogle ? 'Save playlists & history to your account' : 'Sign in with Google first',
            onTap: () => isGoogle ? _runBackup(context, ref) : _showSignInRequired(context),
          ),
          const SizedBox(height: 6),
          _TappableTile(
            icon: Icons.cloud_download_rounded,
            label: 'Restore from Cloud',
            subtitle: isGoogle ? 'Restore playlists from your last backup' : 'Sign in with Google first',
            onTap: () => isGoogle ? _runRestore(context, ref) : _showSignInRequired(context),
          ),

          const SizedBox(height: 20),

          // About, Contact, What's New, Share, Privacy & Rate are in
          // the dedicated About screen — tap Help & Feedback in My Space
          // or navigate to /about.
          const SizedBox(height: 32),
          const Center(child: Text('OTYA Player — Otya? Play.', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Inter', letterSpacing: 0.5))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _runBackup(BuildContext context, [WidgetRef? ref]) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent)),
          SizedBox(width: 14),
          Text('Backing up to cloud…'),
        ],
      ),
      duration: Duration(seconds: 30),
      backgroundColor: AppColors.surface,
    ));
    final userId = ref != null ? (ref.read(authNotifierProvider).userId ?? '') : '';
    final ok = await CloudflareService.instance.backupAll(userId);
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? '✅ Backup complete — playlists & history saved'
          : '❌ Backup failed. Check your connection.'),
      backgroundColor: ok ? AppColors.surface : AppColors.error,
    ));
  }

  Future<void> _runRestore(BuildContext context, [WidgetRef? ref]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore from Cloud?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will merge your cloud playlists with local ones. '
          'No local data will be deleted.',
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Restore',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent)),
          SizedBox(width: 14),
          Text('Restoring from cloud…'),
        ],
      ),
      duration: Duration(seconds: 30),
      backgroundColor: AppColors.surface,
    ));
    final userId = ref != null ? (ref.read(authNotifierProvider).userId ?? '') : '';
    final count = await CloudflareService.instance.restorePlaylists(userId);
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(count >= 0
          ? '✅ Restored $count playlist${count == 1 ? '' : 's'}'
          : '❌ Restore failed. Check your connection.'),
      backgroundColor: count >= 0 ? AppColors.surface : AppColors.error,
    ));
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter')),
        content: const Text(
          'Your playlists and history stay on this device. Sign back in anytime to restore from backup.',
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showSignInRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign in with Google first to use cloud backup.'),
        backgroundColor: AppColors.surface,
      ),
    );
  }

}

// ── Update Checker Tile ────────────────────────────────────────────────────

enum _UpdateState { idle, checking, upToDate, updateAvailable, error }

class _UpdateCheckerTile extends StatefulWidget {
  const _UpdateCheckerTile();

  @override
  State<_UpdateCheckerTile> createState() => _UpdateCheckerTileState();
}

class _UpdateCheckerTileState extends State<_UpdateCheckerTile> {
  _UpdateState _state = _UpdateState.idle;

  Future<void> _check() async {
    setState(() => _state = _UpdateState.checking);
    try {
      final info = await UpdateService.instance.checkForUpdate(force: true);
      if (!mounted) return;
      if (info == null) {
        setState(() => _state = _UpdateState.upToDate);
      } else {
        setState(() => _state = _UpdateState.updateAvailable);
        if (mounted) await UpdateDialog.checkAndShow(context);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _UpdateState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (_state) {
      _UpdateState.idle            => Icons.system_update_outlined,
      _UpdateState.checking        => Icons.sync_rounded,
      _UpdateState.upToDate        => Icons.check_circle_outline_rounded,
      _UpdateState.updateAvailable => Icons.new_releases_rounded,
      _UpdateState.error           => Icons.wifi_off_rounded,
    };
    final subtitle = switch (_state) {
      _UpdateState.idle            => 'Tap to check for a new version',
      _UpdateState.checking        => 'Checking\u2026',
      _UpdateState.upToDate        => 'You have the latest version \u2705',
      _UpdateState.updateAvailable => 'New version available! Tap to update \ud83c\udf89',
      _UpdateState.error           => 'Could not check. Make sure you have internet.',
    };
    final color = switch (_state) {
      _UpdateState.upToDate        => AppColors.accentGreen,
      _UpdateState.updateAvailable => AppColors.accent,
      _UpdateState.error           => AppColors.error,
      _                            => AppColors.textSecondary,
    };

    return GestureDetector(
      onTap: _state == _UpdateState.checking ? null : _check,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _state == _UpdateState.updateAvailable
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.borderOf(context),
          ),
        ),
        child: Row(
          children: [
            _state == _UpdateState.checking
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent))
                : Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Check for Updates',
                      style: TextStyle(
                        fontSize: 14, color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500, fontFamily: 'Inter',
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 11, color: color, fontFamily: 'Inter',
                      )),
                ],
              ),
            ),
            if (_state != _UpdateState.checking)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── About Card (live version from PackageInfo) ──────────────────────────────────────────────

class _AboutCard extends StatefulWidget {
  const _AboutCard();
  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  String _version = '';
  String _build   = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() { _version = info.version; _build = info.buildNumber; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentViolet]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/icons/play_store_512.png',
                width: 56, height: 56, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.accent, size: 56,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('OTYA Player',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
                )),
            const SizedBox(height: 4),
            const Text('Otya? Play. Your media, your rules.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary,
                    fontFamily: 'Inter')),
            const SizedBox(height: 6),
            Text(
              _version.isEmpty ? 'Loading…' : 'Version $_version (build $_build)',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.accent,
                  fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            const Text(
              'A premium offline media player inspired by the Luganda word "Otya?". '
              'Play, organise, and share your local audio and video — no internet required.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary,
                  height: 1.6, fontFamily: 'Inter'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ── What's New Screen ──────────────────────────────────────────────────────

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});
  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}
class _WhatsNewScreenState extends State<WhatsNewScreen> {
  String? _changelog;
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _fetch(); }
  Future<void> _fetch() async {
    try {
      final info = await UpdateService.instance.checkForUpdate(force: true);
      if (mounted) setState(() {
        _changelog = (info?.changelog.isNotEmpty == true)
            ? info!.changelog
            : 'You are on the latest version. No changelog available.';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load changelog.'; _loading = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("What's New", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Text(_changelog ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Inter', height: 1.7)),
                  ),
                ),
    );
  }
}

// ── Account Card ───────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final VoidCallback onSignOut;
  const _AccountCard({this.photoUrl, this.displayName, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: ClipOval(
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _InitialsCircle(name: displayName),
                    )
                  : _InitialsCircle(name: displayName),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName ?? 'Google User',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
                    )),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.accentGreen,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Signed in with Google',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSignOut,
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  final String? name;
  const _InitialsCircle({this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    return Container(
      color: AppColors.accentViolet.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(initials,
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Inter',
          )),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Google Sign-In Button ──────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.6,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('G',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: Color(0xFF4285F4),
                  )),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign in with Google',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
                      )),
                  const Text('Coming soon',
                      style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Inter',
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared tile widgets ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentViolet],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.4, fontFamily: 'Inter',
            )),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon, required this.label,
    this.subtitle, required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 14, color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500, fontFamily: 'Inter',
                    )),
                if (subtitle != null) ...[  
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      )),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
            activeTrackColor: AppColors.accent,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.borderOf(context),
          ),
        ],
      ),
    );
  }
}

class _TappableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  const _TappableTile({
    required this.icon, required this.label,
    this.subtitle, required this.onTap, this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.accent, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14, color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500, fontFamily: 'Inter',
                      )),
                  if (subtitle != null) ...[  
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        )),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── OTYA Account Section ──────────────────────────────────────────────────────

class _OtyaAccountSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OtyaAccountSection> createState() => _OtyaAccountSectionState();
}

class _OtyaAccountSectionState extends ConsumerState<_OtyaAccountSection> {
  UserProfile? _profile;
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!AuthService.instance.isLoggedIn) return;
    setState(() => _loadingProfile = true);
    final p = await AuthService.instance.getProfile();
    if (mounted) setState(() { _profile = p; _loadingProfile = false; });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out of OTYA?',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
        content: const Text(
          'Your local data stays on this device.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.logout();
    ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) setState(() => _profile = null);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
        content: const Text(
          'This permanently deletes your OTYA account and all cloud data. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.deleteAccount();
    ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) setState(() => _profile = null);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.isLoggedIn;

    if (!isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text(
                  'Sign in to sync your music, playlists, and settings across devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.push('/auth'),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Sign In / Register',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_loadingProfile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
        ),
      );
    }

    final profile = _profile;
    final name    = profile?.name ?? AuthService.instance.userName ?? 'OTYA User';
    final email   = profile?.email ?? AuthService.instance.userEmail ?? '';
    final verified = profile?.isVerified ?? AuthService.instance.isVerified;

    return Column(
      children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accentViolet.withValues(alpha: 0.2),
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'O',
                        style: const TextStyle(
                          color: AppColors.accentViolet,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          fontFamily: 'Inter',
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
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (!verified) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Email not verified',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Verify email button (shown if not verified)
        if (!verified) ...[
          _TappableTile(
            icon: Icons.verified_outlined,
            label: 'Verify Email',
            subtitle: 'Enter the code sent to your email',
            onTap: () => context.push('/auth/verify-email'),
          ),
          const SizedBox(height: 6),
        ],
        // Backup to Drive
        _TappableTile(
          icon: Icons.cloud_upload_rounded,
          label: 'Backup to Drive',
          subtitle: 'Save your data to Google Drive',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connect Google Drive in settings to enable backup'),
                backgroundColor: AppColors.surface,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        // Restore from Drive
        _TappableTile(
          icon: Icons.cloud_download_rounded,
          label: 'Restore from Drive',
          subtitle: 'Restore your data from Google Drive',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connect Google Drive in settings to enable restore'),
                backgroundColor: AppColors.surface,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        // Sign out
        _TappableTile(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          subtitle: 'Sign out of your OTYA account',
          onTap: _signOut,
        ),
        const SizedBox(height: 6),
        // Delete account
        _TappableTile(
          icon: Icons.delete_forever_rounded,
          label: 'Delete Account',
          subtitle: 'Permanently delete your account and data',
          onTap: _deleteAccount,
          iconColor: AppColors.error,
        ),
      ],
    );
  }
}
