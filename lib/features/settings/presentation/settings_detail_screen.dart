import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../settings_provider.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';
import 'privacy_policy_screen.dart';

/// Grouped settings screen pushed from My Space hub.
/// Groups: Playback / Storage & Privacy / Updates & About
class SettingsDetailScreen extends ConsumerWidget {
  const SettingsDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s  = ref.watch(settingsProvider);
    final sn = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [

          // ── Appearance ────────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E2B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2F45)),
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
                    onTap: () {
                      HapticFeedback.selectionClick();
                      sn.setThemeMode(mode);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [AppColors.accent, AppColors.accentViolet],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              color: active
                                  ? Colors.black
                                  : AppColors.textSecondary,
                              size: 18),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.black
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          _GroupCard(children: [
            _NavTile(
              icon: Icons.wallpaper_rounded,
              label: 'Customize Wallpaper',
              subtitle: 'Pick a photo or festive theme',
              color: AppColors.accentViolet,
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/theme');
              },
            ),
          ]),

          const SizedBox(height: 24),

          // ── GROUP 1: PLAYBACK ─────────────────────────────────────
          _SectionHeader(label: 'Playback'),
          const SizedBox(height: 10),

          _GroupCard(children: [
            _NavTile(
              icon: Icons.tune_rounded,
              label: 'General',
              subtitle: 'Language, search history, cache',
              color: AppColors.accent,
              onTap: () => _showGeneralSheet(context, ref),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.videocam_rounded,
              label: 'Video',
              subtitle: 'Pop-up play, orientation, auto-resume',
              color: AppColors.accentViolet,
              onTap: () => _showVideoSheet(context, ref),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.headphones_rounded,
              label: 'Audio',
              subtitle: 'Format, equalizer, .nomedia filters',
              color: AppColors.accentGreen,
              onTap: () => _showAudioSheet(context, ref),
            ),
          ]),

          const SizedBox(height: 8),

          // Inline audio toggles
          _GroupCard(children: [
            _SwitchRow(
              icon: Icons.speed_rounded,
              label: 'Default Speed',
              trailing: _Chip(
                label: '${s.playbackSpeed}x',
                onTap: () => _showSpeedPicker(context, sn, s.playbackSpeed),
              ),
            ),
            _Divider(),
            _SwitchRow(
              icon: Icons.queue_music_rounded,
              label: 'Gapless Playback',
              subtitle: 'No silence between tracks',
              value: s.gaplessPlayback,
              onChanged: sn.setGaplessPlayback,
            ),
            _Divider(),
            _SwitchRow(
              icon: Icons.skip_next_rounded,
              label: 'Skip Silence',
              subtitle: 'Auto-skip silent sections',
              value: s.skipSilence,
              onChanged: sn.setSkipSilence,
            ),
            _Divider(),
            _SwitchRow(
              icon: Icons.headphones_rounded,
              label: 'Resume on Headset',
              subtitle: 'Auto-play when headphones connect',
              value: s.autoResume,
              onChanged: sn.setAutoResume,
            ),
            _Divider(),
            _SwitchRow(
              icon: Icons.phone_in_talk_rounded,
              label: 'Pause During Calls',
              value: s.pauseDuringCalls,
              onChanged: sn.setPauseDuringCalls,
            ),
          ]),

          const SizedBox(height: 8),

          // Video toggles
          _GroupCard(children: [
            _SwitchRow(
              icon: Icons.picture_in_picture_alt_rounded,
              label: 'Auto Picture-in-Picture',
              subtitle: 'Float video when you leave the app',
              value: s.autoPip,
              onChanged: sn.setAutoPip,
            ),
            _Divider(),
            _SwitchRow(
              icon: Icons.subtitles_rounded,
              label: 'Auto-load Subtitles',
              subtitle: 'Load .srt/.ass from same folder',
              value: s.autoLoadSubtitles,
              onChanged: sn.setAutoLoadSubtitles,
            ),
            _Divider(),
            _SwitchRow(
              icon: Icons.battery_saver_rounded,
              label: 'Battery Saver by Default',
              subtitle: 'Start video in audio-only mode',
              value: s.defaultBatterySaver,
              onChanged: sn.setDefaultBatterySaver,
            ),
          ]),

          const SizedBox(height: 24),

          // ── GROUP 2: STORAGE & PRIVACY ────────────────────────────
          _SectionHeader(label: 'Storage & Privacy'),
          const SizedBox(height: 10),

          _GroupCard(children: [
            _NavTile(
              icon: Icons.download_rounded,
              label: 'Downloads',
              subtitle: 'Download path, max concurrent tasks',
              color: AppColors.accent,
              onTap: () => _showDownloadsSheet(context, ref),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.security_rounded,
              label: 'Privacy & Security',
              subtitle: 'App lock, biometrics, hide vault',
              color: AppColors.accentViolet,
              onTap: () => _showPrivacySheet(context, ref),
            ),
          ]),

          const SizedBox(height: 8),

          _GroupCard(children: [
            _SwitchRow(
              icon: Icons.lock_rounded,
              label: 'App Lock',
              subtitle: 'Require biometrics to open OTYA Player',
              value: s.appLockEnabled,
              onChanged: sn.setAppLock,
            ),
            _Divider(),
            _SwitchRow(
              icon: Icons.visibility_off_rounded,
              label: 'Hide Vault from Recents',
              subtitle: 'Blur screenshot when switching apps',
              value: s.hideVaultFromRecents,
              onChanged: sn.setHideVaultFromRecents,
            ),
            _Divider(),
            _NavTile(
              icon: Icons.admin_panel_settings_rounded,
              label: 'Manage App Permissions',
              subtitle: 'Storage, Bluetooth, Notifications',
              color: AppColors.textSecondary,
              onTap: openAppSettings,
            ),
          ]),

          const SizedBox(height: 24),

          // ── GROUP 3: UPDATES & ABOUT ──────────────────────────────
          _SectionHeader(label: 'Updates & About'),
          const SizedBox(height: 10),

          _GroupCard(children: [
            _NavTile(
              icon: Icons.info_outline_rounded,
              label: 'About OTYA Player',
              subtitle: 'Version, support & what\'s new',
              color: AppColors.accent,
              onTap: () => context.push('/about'),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.system_update_outlined,
              label: 'Check for Updates',
              subtitle: 'Tap to check for a new version',
              color: AppColors.accent,
              onTap: () {},
            ),
            _Divider(),
            _NavTile(
              icon: Icons.email_outlined,
              label: 'Contact Support',
              subtitle: 'support@petersmartlink.com',
              color: AppColors.textSecondary,
              onTap: () => _launchEmail(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.new_releases_outlined,
              label: "What's New",
              subtitle: 'See what changed in this version',
              color: AppColors.textSecondary,
              onTap: () {},
            ),
            _Divider(),
            _NavTile(
              icon: Icons.share_rounded,
              label: 'Share App',
              subtitle: 'Send OTYA Player to a friend',
              color: AppColors.textSecondary,
              onTap: () => _shareApp(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              color: AppColors.textSecondary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.star_outline_rounded,
              label: 'Rate OTYA Player',
              subtitle: 'Enjoying the app? Leave a review!',
              color: AppColors.accentAmber,
              onTap: () => _launchUrl(context,
                  'https://play.google.com/store/apps/details?id=com.otyaplayer.app'),
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Bottom-sheet helpers ──────────────────────────────────────────────

  /// Shared drag-handle + title header used by every bottom sheet.
  Widget _sheetHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        const Divider(color: AppColors.border, height: 24),
      ],
    );
  }

  // ── General ───────────────────────────────────────────────────────────

  void _showGeneralSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, sheetRef, __) {
          final s  = sheetRef.watch(settingsProvider);
          final sn = sheetRef.read(settingsProvider.notifier);
          return StatefulBuilder(
            builder: (ctx2, setSheetState) {
              // Local stub state for search-history toggle (no backing store yet).
              bool searchHistoryEnabled = true;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20, 16, 20,
                  MediaQuery.of(ctx2).viewInsets.bottom + 32,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetHeader('General'),

                      // Language selector
                      const Text(
                        'Language',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...{
                        'en': 'English',
                        'fr': 'French',
                        'es': 'Spanish',
                        'sw': 'Swahili',
                      }.entries.map((e) {
                        final selected = s.language == e.key;
                        return RadioListTile<String>(
                          value: e.key,
                          groupValue: s.language,
                          onChanged: (v) {
                            if (v != null) {
                              HapticFeedback.selectionClick();
                              sn.setLanguage(v);
                            }
                          },
                          title: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                              fontFamily: 'Inter',
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      }),

                      const Divider(color: AppColors.border, height: 24),

                      // Search history toggle (stub)
                      SwitchListTile(
                        value: searchHistoryEnabled,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setSheetState(() => searchHistoryEnabled = v);
                        },
                        title: const Text(
                          'Search History',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                        ),
                        subtitle: const Text(
                          'Remember recent searches',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                          ),
                        ),
                        activeThumbColor: Colors.black,
                        activeTrackColor: AppColors.accent,
                        inactiveThumbColor: AppColors.textSecondary,
                        inactiveTrackColor: AppColors.border,
                        contentPadding: EdgeInsets.zero,
                      ),

                      const Divider(color: AppColors.border, height: 24),

                      // Clear cache button
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_sweep_rounded,
                              color: Colors.redAccent, size: 18),
                        ),
                        title: const Text(
                          'Clear Cache',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                        ),
                        subtitle: const Text(
                          'Free up temporary storage',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary, size: 18),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx2);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cache cleared')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Video ─────────────────────────────────────────────────────────────

  void _showVideoSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, sheetRef, __) {
          final s  = sheetRef.watch(settingsProvider);
          final sn = sheetRef.read(settingsProvider.notifier);
          return StatefulBuilder(
            builder: (ctx2, setSheetState) {
              // Stub local state for toggles without a backing store yet.
              bool orientationLocked = false;
              bool continuousPlayback = true;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20, 16, 20,
                  MediaQuery.of(ctx2).viewInsets.bottom + 32,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetHeader('Video'),

                      _SheetSwitch(
                        label: 'Pop-up Play',
                        subtitle: 'Float video when you leave the app',
                        value: s.autoPip,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          sn.setAutoPip(v);
                        },
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      _SheetSwitch(
                        label: 'Lock Screen Orientation',
                        subtitle: 'Prevent auto-rotate during playback',
                        value: orientationLocked,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setSheetState(() => orientationLocked = v);
                        },
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      _SheetSwitch(
                        label: 'Continuous Playback',
                        subtitle: 'Auto-play next video in folder',
                        value: continuousPlayback,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setSheetState(() => continuousPlayback = v);
                        },
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      _SheetSwitch(
                        label: 'Auto-Resume',
                        subtitle: 'Resume from where you left off',
                        value: s.autoResume,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          sn.setAutoResume(v);
                        },
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      _SheetSwitch(
                        label: 'Auto-load Subtitles',
                        subtitle: 'Load .srt/.ass from same folder',
                        value: s.autoLoadSubtitles,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          sn.setAutoLoadSubtitles(v);
                        },
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      _SheetSwitch(
                        label: 'Battery Saver by Default',
                        subtitle: 'Start video in audio-only mode',
                        value: s.defaultBatterySaver,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          sn.setDefaultBatterySaver(v);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Audio ─────────────────────────────────────────────────────────────

  void _showAudioSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, sheetRef, __) {
          final s  = sheetRef.watch(settingsProvider);
          final sn = sheetRef.read(settingsProvider.notifier);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20, 16, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHeader('Audio'),

                  _SheetSwitch(
                    label: 'Gapless Playback',
                    subtitle: 'No silence between tracks',
                    value: s.gaplessPlayback,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setGaplessPlayback(v);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _SheetSwitch(
                    label: 'Skip Silence',
                    subtitle: 'Auto-skip silent sections',
                    value: s.skipSilence,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setSkipSilence(v);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _SheetSwitch(
                    label: 'Resume on Headset',
                    subtitle: 'Auto-play when headphones connect',
                    value: s.autoResume,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setAutoResume(v);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _SheetSwitch(
                    label: 'Pause During Calls',
                    subtitle: 'Pause playback when a call arrives',
                    value: s.pauseDuringCalls,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setPauseDuringCalls(v);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _SheetSwitch(
                    label: 'Now Playing Notification',
                    subtitle: 'Show media controls in notification bar',
                    value: s.nowPlayingNotification,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setNowPlayingNotification(v);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 24),

                  // .nomedia info tile
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '.nomedia folders\n'
                            'Place an empty file named ".nomedia" in any folder '
                            'to hide its contents from OTYA Player\'s media scanner.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'Inter',
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Downloads ─────────────────────────────────────────────────────────

  void _showDownloadsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          int maxConcurrent = 2; // stub default
          String downloadPath = 'Loading…';

          // Kick off async path resolution once.
          getApplicationDocumentsDirectory().then((dir) {
            if (ctx.mounted) {
              setSheetState(() => downloadPath = dir.path);
            }
          });

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20, 16, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHeader('Downloads'),

                  // Download path (read-only)
                  const Text(
                    'Download Location',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      downloadPath,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),

                  const Divider(color: AppColors.border, height: 28),

                  // Max concurrent tasks
                  const Text(
                    'Max Concurrent Downloads',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [1, 2, 3].map((n) {
                      final active = maxConcurrent == n;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setSheetState(() => maxConcurrent = n);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.accent
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active
                                    ? AppColors.accent
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.black
                                    : AppColors.textPrimary,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Privacy & Security ────────────────────────────────────────────────

  void _showPrivacySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, sheetRef, __) {
          final s  = sheetRef.watch(settingsProvider);
          final sn = sheetRef.read(settingsProvider.notifier);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20, 16, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHeader('Privacy & Security'),

                  _SheetSwitch(
                    label: 'App Lock',
                    subtitle: 'Require biometrics to open OTYA Player',
                    value: s.appLockEnabled,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setAppLock(v);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 24),

                  // Biometrics info tile
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.fingerprint_rounded,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Biometrics\n'
                            'Uses device biometrics (fingerprint or face) '
                            'when App Lock is enabled.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'Inter',
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: AppColors.border, height: 24),

                  _SheetSwitch(
                    label: 'Hide Vault from Recents',
                    subtitle: 'Blur screenshot when switching apps',
                    value: s.hideVaultFromRecents,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setHideVaultFromRecents(v);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSpeedPicker(
      BuildContext context, SettingsNotifier sn, double current) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Default Playback Speed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
                    child: Text(
                      '${sp}x',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.black : AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
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
      path: 'support@petersmartlink.com',
      queryParameters: {'subject': 'OTYA Player Support'},
    );
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      await Share.share(
        'Download OTYA Player v${info.version} — free offline media player:\n'
        'https://getotya.petersmartlink.com/download',
        subject: 'OTYA Player',
      );
    } catch (_) {}
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
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
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.4,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2F45)),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFF2A2F45),
      indent: 16,
      endIndent: 16,
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  const _SwitchRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            )
          : null,
      trailing: trailing ??
          (value != null && onChanged != null
              ? Switch(
                  value: value!,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    onChanged!(v);
                  },
                  activeThumbColor: Colors.black,
                  activeTrackColor: AppColors.accent,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.border,
                )
              : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

/// Compact switch row used inside bottom sheets.
class _SheetSwitch extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SheetSwitch({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            )
          : null,
      activeThumbColor: Colors.black,
      activeTrackColor: AppColors.accent,
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.border,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});

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
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}


