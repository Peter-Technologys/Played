import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/appwrite_service.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_folder_service.dart';
import '../../features/my_space/presentation/providers/my_space_provider.dart';
import '../settings/presentation/privacy_policy_screen.dart';
import '../../shared/widgets/played_logo.dart';
import '../settings/settings_provider.dart';

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
    final isGoogle    = ref.watch(isGoogleSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final photoUrl    = ref.watch(photoUrlProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Profile & Settings',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Inter',
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [

          // ── 1. APPEARANCE ─────────────────────────────────────────────
          const _SectionHeader(label: 'Appearance'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: AppThemeMode.values.map((mode) {
                final label = switch (mode) {
                  AppThemeMode.dark   => 'Dark',
                  AppThemeMode.amoled => 'AMOLED',
                  AppThemeMode.light  => 'Light',
                };
                final icon = switch (mode) {
                  AppThemeMode.dark   => Icons.dark_mode_rounded,
                  AppThemeMode.amoled => Icons.brightness_1_rounded,
                  AppThemeMode.light  => Icons.light_mode_rounded,
                };
                final active = s.themeMode == mode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => sn.setThemeMode(mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [AppColors.accent, AppColors.accentViolet])
                            : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              color: active ? Colors.black : AppColors.textSecondary,
                              size: 18),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: active ? Colors.black : AppColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // ── 2. ACCOUNT ────────────────────────────────────────────────
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

          // ── 3. AUDIO ──────────────────────────────────────────────────
          const _SectionHeader(label: 'Audio'),
          const SizedBox(height: 8),
          _CollapsibleSection(
            children: [
              _SettingsTile(
                icon: Icons.speed_rounded,
                label: 'Default Playback Speed',
                trailing: _ValueChip(
                  label: '${s.playbackSpeed}x',
                  onTap: () => _showSpeedPicker(context, sn, s.playbackSpeed),
                ),
              ),
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.queue_music_rounded,
                label: 'Gapless Playback',
                subtitle: 'No silence between tracks',
                value: s.gaplessPlayback,
                onChanged: sn.setGaplessPlayback,
              ),
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.swap_horiz_rounded,
                label: 'Crossfade',
                subtitle: 'Blend tracks smoothly',
                value: s.crossfadeDuration > 0,
                onChanged: (v) => sn.setCrossfade(v ? 3.0 : 0.0),
              ),
              if (s.crossfadeDuration > 0) ...[  
                const SizedBox(height: 6),
                _SettingsTile(
                  icon: Icons.timer_outlined,
                  label: 'Crossfade Duration',
                  trailing: _ValueChip(
                    label: '${s.crossfadeDuration.toInt()}s',
                    onTap: () => _showCrossfadePicker(context, sn, s.crossfadeDuration),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.skip_next_rounded,
                label: 'Skip Silence',
                subtitle: 'Auto-skip silent sections',
                value: s.skipSilence,
                onChanged: sn.setSkipSilence,
              ),
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.headphones_rounded,
                label: 'Resume on Headset',
                subtitle: 'Auto-play when headphones connect',
                value: s.autoResume,
                onChanged: sn.setAutoResume,
              ),
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.phone_in_talk_rounded,
                label: 'Pause During Calls',
                subtitle: 'Auto-pause when a call comes in',
                value: s.pauseDuringCalls,
                onChanged: sn.setPauseDuringCalls,
              ),
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.notifications_rounded,
                label: 'Now Playing Notification',
                subtitle: 'Show media controls in notification bar',
                value: s.nowPlayingNotification,
                onChanged: sn.setNowPlayingNotification,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 4. VIDEO ──────────────────────────────────────────────────
          const _SectionHeader(label: 'Video'),
          const SizedBox(height: 8),
          _CollapsibleSection(
            children: [
              _SwitchTile(
                icon: Icons.battery_saver_rounded,
                label: 'Battery Saver by Default',
                subtitle: 'Start video player in audio-only mode',
                value: s.defaultBatterySaver,
                onChanged: sn.setDefaultBatterySaver,
              ),
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.picture_in_picture_alt_rounded,
                label: 'Auto Picture-in-Picture',
                subtitle: 'Float video when you leave the app',
                value: s.autoPip,
                onChanged: sn.setAutoPip,
              ),
              const SizedBox(height: 6),
              _SwitchTile(
                icon: Icons.subtitles_rounded,
                label: 'Auto-load Subtitles',
                subtitle: 'Load .srt/.ass from same folder as video',
                value: s.autoLoadSubtitles,
                onChanged: sn.setAutoLoadSubtitles,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 5. PRIVACY & SECURITY ─────────────────────────────────────
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

          // ── 6. BACKUP & SYNC ──────────────────────────────────────────
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

          // ── 7. LIBRARY ────────────────────────────────────────────────
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

          // ── 8. ABOUT ──────────────────────────────────────────────────
          const _SectionHeader(label: 'About'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const PlayedLogo(fontSize: 18, letterSpacing: 3,
                      borderRadius: 10,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  const SizedBox(height: 12),
                  const Text('Otya? Play. Your media, your rules.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary,
                          fontFamily: 'Inter')),
                  const SizedBox(height: 4),
                  const Text('Version 1.2.0 (build 3)',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted,
                          fontFamily: 'Inter')),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'OTYA Player is a premium offline media player inspired by the Luganda word "Otya?". '
                    'Play, organise, and share your local audio and video — no internet required.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary,
                        height: 1.6, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.business_rounded,
            label: 'Developer',
            trailing: const Text('OTYA Player Team',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary,
                    fontFamily: 'Inter')),
          ),
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
            subtitle: 'Version 1.2.0 release notes',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WhatsNewScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _TappableTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
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

  // ── Pickers ────────────────────────────────────────────────────────────────

  void _showSpeedPicker(BuildContext context, SettingsNotifier sn, double current) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Default Playback Speed',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: speeds.map((sp) {
                final active = sp == current;
                return GestureDetector(
                  onTap: () {
                    sn.setPlaybackSpeed(sp);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active ? AppColors.accent : AppColors.border),
                    ),
                    child: Text('${sp}x',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textPrimary,
                          fontFamily: 'Inter',
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showCrossfadePicker(
      BuildContext context, SettingsNotifier sn, double current) {
    const options = [1, 2, 3, 5, 8, 10];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Crossfade Duration',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: options.map((sec) {
                final active = sec == current.toInt();
                return GestureDetector(
                  onTap: () {
                    sn.setCrossfade(sec.toDouble());
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active ? AppColors.accent : AppColors.border),
                    ),
                    child: Text('${sec}s',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textPrimary,
                          fontFamily: 'Inter',
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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
              AuthService.instance.signOut();
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
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
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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

// ── What's New Screen ──────────────────────────────────────────────────────

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  static const _sections = [
    _ChangeSection(
      version: '1.2.0',
      date: 'June 2026',
      isLatest: true,
      items: [
        _ChangeItem(Icons.video_library_rounded, AppColors.accent,
            'Video Thumbnails', 'Real video frames shown in the grid.'),
        _ChangeItem(Icons.album_rounded, AppColors.accentViolet,
            'Album Art', 'Real cover art from your music files.'),
        _ChangeItem(Icons.directions_car_rounded, AppColors.accent,
            'Car Mode', 'Large-button layout for safe driving.'),
        _ChangeItem(Icons.drive_file_rename_outline_rounded, AppColors.accentViolet,
            'File Management', 'Rename and delete files from inside the app.'),
        _ChangeItem(Icons.lyrics_rounded, AppColors.accent,
            'Offline Lyrics', 'Lyrics cached locally after first fetch.'),
        _ChangeItem(Icons.subtitles_rounded, AppColors.accentViolet,
            'Auto Subtitles', 'Loads .srt/.ass automatically with videos.'),
      ],
    ),
    _ChangeSection(
      version: '1.1.0',
      date: 'May 2026',
      isLatest: false,
      items: [
        _ChangeItem(Icons.queue_music_rounded, AppColors.accent,
            'Playlists', 'Create, rename, reorder and play playlists.'),
        _ChangeItem(Icons.picture_in_picture_alt_rounded, AppColors.accentViolet,
            'PiP Auto-Mode', 'Video floats when you leave the app.'),
        _ChangeItem(Icons.folder_special_rounded, AppColors.accent,
            'Full SD Card Access', 'MANAGE_EXTERNAL_STORAGE support.'),
        _ChangeItem(Icons.tab_rounded, AppColors.accentViolet,
            'Songs / Videos / Folders tabs', 'Organised like PlayIt.'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("What's New",
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Inter',
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

class _ChangeSection {
  final String version;
  final String date;
  final bool isLatest;
  final List<_ChangeItem> items;
  const _ChangeSection({
    required this.version, required this.date,
    required this.isLatest, required this.items,
  });
}

class _ChangeItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _ChangeItem(this.icon, this.color, this.title, this.description);
}

class _SectionWidget extends StatelessWidget {
  final _ChangeSection section;
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
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
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
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary, fontFamily: 'Inter',
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
        color: AppColors.surface,
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
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, fontFamily: 'Inter',
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                )),
            SizedBox(width: 12),
            Text('Sign in with Google',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
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

class _ValueChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ValueChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.accent, fontFamily: 'Inter',
            )),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  const _SettingsTile({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500, fontFamily: 'Inter',
                )),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Collapsible Section ────────────────────────────────────────────────────

class _CollapsibleSection extends StatefulWidget {
  final List<Widget> children;
  const _CollapsibleSection({required this.children});

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  _expanded ? 'Collapse' : 'Expand',
                  style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary, size: 16,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.children,
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                    style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary,
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
            inactiveTrackColor: AppColors.border,
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
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
                      style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary,
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
