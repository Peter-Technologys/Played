import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/appwrite_service.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../../core/services/auth_provider.dart';

import '../../core/services/storage_folder_service.dart';
import '../../features/my_space/presentation/providers/my_space_provider.dart';
import '../../shared/widgets/played_logo.dart';
import '../settings/settings_provider.dart';
import '../../core/config/changelog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile & Settings Screen
//   Appearance → Account → Audio → Video → Privacy & Security →
//   Backup & Sync → Library → About
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s           = ref.watch(settingsProvider);
    final sn          = ref.read(settingsProvider.notifier);
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
        title: Text('Profile & Settings',
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
              onTap: () => _signInWithGoogle(context, ref),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            const Text(
              'Sign in with Google to back up your playlists and play history to your account.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ],

          const SizedBox(height: 20),

          // ── 2. PRIVACY & SECURITY ─────────────────────────────────────
          const _SectionHeader(label: 'Privacy & Security'),
          const SizedBox(height: 12),
          _SwitchTile(
            icon: Icons.lock_rounded,
            label: 'App Lock',
            subtitle: 'Require biometrics to open OTYA Player',
            value: s.appLockEnabled,
            onChanged: sn.setAppLock,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.visibility_off_rounded,
            label: 'Hide Vault from Recents',
            subtitle: 'Blur screenshot when switching apps',
            value: s.hideVaultFromRecents,
            onChanged: sn.setHideVaultFromRecents,
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.security_rounded,
            label: 'Manage App Permissions',
            subtitle: 'Storage, Bluetooth, Notifications',
            onTap: openAppSettings,
          ),

          const SizedBox(height: 20),

          // ── 3. BACKUP & SYNC ──────────────────────────────────────────
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
            onTap: () => isGoogle ? _runBackup(context) : _showSignInRequired(context),
          ),
          const SizedBox(height: 6),
          _TappableTile(
            icon: Icons.cloud_download_rounded,
            label: 'Restore from Cloud',
            subtitle: isGoogle ? 'Restore playlists from your last backup' : 'Sign in with Google first',
            onTap: () => isGoogle ? _runRestore(context) : _showSignInRequired(context),
          ),

          const SizedBox(height: 20),

          // ── 4. LIBRARY ────────────────────────────────────────────────
          const _SectionHeader(label: 'Library'),
          const SizedBox(height: 12),
          _TappableTile(
            icon: Icons.refresh_rounded,
            label: 'Rescan Library',
            subtitle: 'Find new files added to your device',
            onTap: () {
              ref.read(mediaLibraryProvider.notifier).refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rescanning library in background…'),
                  backgroundColor: AppColors.surface,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Clear Cache',
            subtitle: 'Remove temporary processing files',
            onTap: () => _confirmClearCache(context),
          ),
          const SizedBox(height: 8),
          _StorageSection(),

          const SizedBox(height: 20),

          // ── 5. APP UPDATES ────────────────────────────────────────────
          const _SectionHeader(label: 'App Updates'),
          const SizedBox(height: 12),
          const _UpdateCheckerTile(),

          const SizedBox(height: 20),

          // ── 6. ABOUT ──────────────────────────────────────────────────
          const _SectionHeader(label: 'About'),
          const SizedBox(height: 12),
          const _AboutCard(),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.email_outlined,
            label: 'Contact Support',
            subtitle: 'support@petersmartlink.com',
            onTap: () => _launchEmail(context),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.new_releases_outlined,
            label: "What's New",
            subtitle: 'See what changed in this version',
            onTap: () => context.push('/whats-new'),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.share_rounded,
            label: 'Share App',
            subtitle: 'Send OTYA Player to a friend',
            onTap: () => _shareApp(context),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => context.push('/privacy'),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.star_outline_rounded,
            label: 'Rate OTYA Player',
            subtitle: 'Enjoying the app? Leave a review!',
            onTap: () => _launchUrl(context,
                'https://play.google.com/store/apps/details?id=com.otyaplayer.app'),
          ),
          const SizedBox(height: 32),
          const Center(child: PlayedFooter()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _confirmClearCache(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cache?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Temporary files will be deleted. Your media and playlists are safe.',
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
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final tmp = await getTemporaryDirectory();
      for (final name in ['video_thumbs', 'album_art']) {
        final dir = Directory('${tmp.path}/$name');
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Cache cleared'),
          backgroundColor: AppColors.surface),
    );
  }

  Future<void> _runBackup(BuildContext context) async {
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
    final ok = await AppwriteService.instance.backupAll();
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? '✅ Backup complete — playlists & history saved'
          : '❌ Backup failed. Check your connection.'),
      backgroundColor: ok ? AppColors.surface : AppColors.error,
    ));
  }

  Future<void> _runRestore(BuildContext context) async {
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
    final count = await AppwriteService.instance.restorePlaylists();
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(count >= 0
          ? '✅ Restored $count playlist${count == 1 ? '' : 's'}'
          : '❌ Restore failed. Check your connection.'),
      backgroundColor: count >= 0 ? AppColors.surface : AppColors.error,
    ));
  }

  Future<void> _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      await AppwriteService.instance.signInWithGoogle();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Google sign-in…'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
            onPressed: () {
              Navigator.pop(context);
              AppwriteService.instance.signOut();
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

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@petersmartlink.com',
      queryParameters: {'subject': 'OTYA Player Support'},
    );
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open email app.'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      await Share.share(
        'Download OTYA Player v${info.version} — free offline media player for Android:\n'
        'https://getotya.petersmartlink.com/download',
        subject: 'OTYA Player',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    // Try in-app browser first, fall back to external app
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
    );
    if (!launched) {
      final fallback = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!fallback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open link.'),
              backgroundColor: AppColors.error),
        );
      }
    }
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

// ── Storage Section ────────────────────────────────────────────────────────

class _StorageSection extends StatefulWidget {
  @override
  State<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<_StorageSection> {
  Map<String, String> _paths = {};

  @override
  void initState() {
    super.initState();
    StorageFolderService.instance.storageSummary().then((m) {
      if (mounted) setState(() => _paths = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_paths.isEmpty) return const SizedBox.shrink();
    return Column(
      children: _paths.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_rounded,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                      const SizedBox(height: 2),
                      Text(e.value,
                          style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  // Changelog data is sourced from lib/core/config/changelog.dart.
  static const _sections = changelog;

  @override
  Widget build(BuildContext context) {
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
        title: Text("What's New",
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: _sections
            .asMap()
            .entries
            .map((e) => _SectionWidget(section: e.value)
                .animate()
                .fadeIn(duration: 400.ms,
                    delay: Duration(milliseconds: e.key * 120))
                .slideY(begin: 0.05, end: 0))
            .toList(),
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final ChangeSection section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text('v${section.version}',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
                )),
            const SizedBox(width: 10),
            if (section.isLatest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Text('LATEST',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.accent, fontFamily: 'Inter',
                      letterSpacing: 0.8,
                    )),
              ),
            const Spacer(),
            Text(section.date,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        ...section.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
                            )),
                        const SizedBox(height: 2),
                        Text(item.description,
                            style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary,
                              height: 1.5, fontFamily: 'Inter',
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 8),
        const Divider(color: AppColors.border, height: 1),
      ],
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
            Text('Sign in with Google',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter',
                )),
          ],
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
  const _TappableTile({
    required this.icon, required this.label,
    this.subtitle, required this.onTap,
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
            Icon(icon, color: AppColors.accent, size: 20),
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
