import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_folder_service.dart';
import '../../../features/my_space/presentation/providers/my_space_provider.dart';
import '../../../shared/widgets/played_logo.dart';
import '../../settings/settings_provider.dart';
import '../../settings/presentation/privacy_policy_screen.dart';

// ───────────────────────────────────────────────────────────────────────────────
// Profile Screen — Account + Settings + Backup in one place
// ───────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s           = ref.watch(settingsProvider);
    final sn          = ref.read(settingsProvider.notifier);
    final isSignedIn  = ref.watch(isSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final email       = ref.watch(userEmailProvider);

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [

          // ── ACCOUNT ───────────────────────────────────────────────────────────────
          const _SectionHeader(label: 'Account'),
          const SizedBox(height: 12),

          if (isSignedIn) ...[  
            _SignedInCard(
              displayName: displayName,
              email: email,
              onSignOut: () => _confirmSignOut(context, ref),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 12),
            _BackupCard(onBackup: () => _runBackup(context),
                        onRestore: () => _runRestore(context)),
          ] else ...[  
            _GoogleSignInButton(
              onTap: () => _signInWithGoogle(context),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            const Text(
              'Sign in with Google to back up your playlists and play history to your account.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ],

          const SizedBox(height: 32),

          // ── APPEARANCE ────────────────────────────────────────────────────────────
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

          const SizedBox(height: 32),

          // ── AUDIO ───────────────────────────────────────────────────────────────────
          const _SectionHeader(label: 'Audio'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.speed_rounded,
            label: 'Default Playback Speed',
            trailing: _ValueChip(
              label: '${s.playbackSpeed}x',
              onTap: () => _showSpeedPicker(context, sn, s.playbackSpeed),
            ),
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.queue_music_rounded,
            label: 'Gapless Playback',
            subtitle: 'No silence between tracks',
            value: s.gaplessPlayback,
            onChanged: sn.setGaplessPlayback,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.swap_horiz_rounded,
            label: 'Crossfade',
            subtitle: 'Blend tracks smoothly',
            value: s.crossfadeDuration > 0,
            onChanged: (v) => sn.setCrossfade(v ? 3.0 : 0.0),
          ),
          if (s.crossfadeDuration > 0) ...[
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.timer_outlined,
              label: 'Crossfade Duration',
              trailing: _ValueChip(
                label: '${s.crossfadeDuration.toInt()}s',
                onTap: () => _showCrossfadePicker(context, sn, s.crossfadeDuration),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.skip_next_rounded,
            label: 'Skip Silence',
            subtitle: 'Auto-skip silent sections',
            value: s.skipSilence,
            onChanged: sn.setSkipSilence,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.headphones_rounded,
            label: 'Resume on Headset',
            subtitle: 'Auto-play when headphones connect',
            value: s.autoResume,
            onChanged: sn.setAutoResume,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.phone_in_talk_rounded,
            label: 'Pause During Calls',
            subtitle: 'Auto-pause when a call comes in',
            value: s.pauseDuringCalls,
            onChanged: sn.setPauseDuringCalls,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.notifications_rounded,
            label: 'Now Playing Notification',
            subtitle: 'Show media controls in notification bar',
            value: s.nowPlayingNotification,
            onChanged: sn.setNowPlayingNotification,
          ),

          const SizedBox(height: 32),

          // ── VIDEO ───────────────────────────────────────────────────────────────────
          const _SectionHeader(label: 'Video'),
          const SizedBox(height: 12),
          _SwitchTile(
            icon: Icons.battery_saver_rounded,
            label: 'Battery Saver by Default',
            subtitle: 'Start video player in audio-only mode',
            value: s.defaultBatterySaver,
            onChanged: sn.setDefaultBatterySaver,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.picture_in_picture_alt_rounded,
            label: 'Auto Picture-in-Picture',
            subtitle: 'Float video when you leave the app',
            value: s.autoPip,
            onChanged: sn.setAutoPip,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.subtitles_rounded,
            label: 'Auto-load Subtitles',
            subtitle: 'Load .srt/.ass from same folder as video',
            value: s.autoLoadSubtitles,
            onChanged: sn.setAutoLoadSubtitles,
          ),

          const SizedBox(height: 32),

          // ── PRIVACY & SECURITY ────────────────────────────────────────────────────────
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

          const SizedBox(height: 32),

          // ── LIBRARY ───────────────────────────────────────────────────────────────────
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

          const SizedBox(height: 32),

          // ── ABOUT ───────────────────────────────────────────────────────────────────
          const _SectionHeader(label: 'About'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  PlayedLogo(fontSize: 24, letterSpacing: 4,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  SizedBox(height: 12),
                  Text('Otya? Play.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary,
                          fontFamily: 'Inter')),
                  SizedBox(height: 4),
                  Text('Version 1.2.0 (build 3)',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted,
                          fontFamily: 'Inter')),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 12),
          _TappableTile(
            icon: Icons.email_outlined,
            label: 'Contact Support',
            subtitle: 'dev@petersmartlink.com',
            onTap: () => _launchEmail(context),
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
                'https://play.google.com/store/apps/details?id=com.petersmartlink.otya'),
          ),
          const SizedBox(height: 32),
          const Center(child: PlayedFooter()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      await AppwriteService.instance.signInWithGoogle();
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
                fontWeight: FontWeight.w700)),
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

  Future<void> _runBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
        SizedBox(width: 14),
        Text('Backing up to your Google account…'),
      ]),
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
        title: const Text('Restore from backup?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will merge your cloud playlists with local ones. No local data will be deleted.',
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
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
        SizedBox(width: 14),
        Text('Restoring from cloud…'),
      ]),
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
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Default Playback Speed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: speeds.map((sp) {
                final active = sp == current;
                return GestureDetector(
                  onTap: () { sn.setPlaybackSpeed(sp); Navigator.pop(context); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppColors.accent : AppColors.border),
                    ),
                    child: Text('${sp}x',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textPrimary,
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

  void _showCrossfadePicker(BuildContext context, SettingsNotifier sn, double current) {
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
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Crossfade Duration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: options.map((sec) {
                final active = sec == current.toInt();
                return GestureDetector(
                  onTap: () { sn.setCrossfade(sec.toDouble()); Navigator.pop(context); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppColors.accent : AppColors.border),
                    ),
                    child: Text('${sec}s',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textPrimary,
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

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'dev@petersmartlink.com',
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
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open link.'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ── Signed-In Card ──────────────────────────────────────────────────────────────────

class _SignedInCard extends StatelessWidget {
  final String? displayName;
  final String? email;
  final VoidCallback onSignOut;
  const _SignedInCard({this.displayName, this.email, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName ?? email ?? '?');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8A2BE2).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Avatar circle with initials
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white, fontFamily: 'Inter',
                )),
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
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(email!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Signed in with Google',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
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

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Backup Card ─────────────────────────────────────────────────────────────────────

class _BackupCard extends StatelessWidget {
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  const _BackupCard({required this.onBackup, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cloud Backup',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontFamily: 'Inter',
              )),
          const SizedBox(height: 4),
          const Text('Playlists and play history are backed up to your Google account.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onBackup,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Back Up Now',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onRestore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_download_rounded,
                            color: AppColors.textSecondary, size: 16),
                        SizedBox(width: 6),
                        Text('Restore',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Google Sign-In Button ──────────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google 'G' logo colours
            Text('G',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                )),
            SizedBox(width: 12),
            Text('Continue with Google',
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

// ── Storage Section ──────────────────────────────────────────────────────────────────

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

// ── Shared tile widgets ────────────────────────────────────────────────────────────────

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
              colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
