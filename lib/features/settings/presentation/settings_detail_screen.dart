import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/services/update_service.dart';
import '../../../core/widgets/update_dialog.dart';
import '../settings_provider.dart';
import '../../my_space/presentation/providers/my_space_provider.dart';


/// Grouped settings screen pushed from My Space hub.
/// Groups: Playback / Storage & Privacy / Updates & About
class SettingsDetailScreen extends ConsumerStatefulWidget {
  const SettingsDetailScreen({super.key});

  @override
  ConsumerState<SettingsDetailScreen> createState() => _SettingsDetailScreenState();
}

class _SettingsDetailScreenState extends ConsumerState<SettingsDetailScreen> {
  bool _checkingUpdate = false;

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final update = await UpdateService.instance.checkForUpdate(force: true);
      if (!mounted) return;
      if (update != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdateDialog(info: update),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have the latest version ✅')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check for updates. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s  = ref.watch(settingsProvider);
    final sn = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 100),
        children: [

          // ── Theme & Appearance ────────────────────────────────────
          _GroupCard(children: [
            _NavTile(
              icon: Icons.palette_rounded,
              label: 'Theme & Appearance',
              subtitle: 'Dark, AMOLED, Light & wallpaper',
              color: AppColors.accentViolet,
              onTap: () => context.push('/theme'),
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

          // Default Speed (not duplicated in any sheet)
          _GroupCard(children: [
            _SwitchRow(
              icon: Icons.speed_rounded,
              label: 'Default Speed',
              trailing: _Chip(
                label: '${s.playbackSpeed}x',
                onTap: () => _showSpeedPicker(context, sn, s.playbackSpeed),
              ),
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
              label: 'About & Support',
              subtitle: 'Version, links & what\'s new',
              color: AppColors.accent,
              onTap: () => context.push('/about'),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.system_update_outlined,
              label: 'Check for Updates',
              subtitle: _checkingUpdate ? 'Checking…' : 'Tap to check for a new version',
              color: AppColors.accent,
              onTap: _checkingUpdate ? () {} : _checkForUpdate,
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

                  // Search history toggle — persisted via settingsProvider
                  SwitchListTile(
                    value: s.searchHistory,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setSearchHistory(v);
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

                  // Clear cache button — real implementation
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
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                      await _clearCache(context);
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
                    value: s.orientationLocked,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setOrientationLocked(v);
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _SheetSwitch(
                    label: 'Continuous Playback',
                    subtitle: 'Auto-play next video in folder',
                    value: s.continuousPlayback,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      sn.setContinuousPlayback(v);
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
      builder: (_) => Consumer(
        builder: (ctx, sheetRef, __) {
          final s  = sheetRef.watch(settingsProvider);
          final sn = sheetRef.read(settingsProvider.notifier);
          return _DownloadsSheetBody(s: s, sn: sn);
        },
      ),
    );
  }

  // ── Cache clearing ────────────────────────────────────────────────────

  Future<void> _clearCache(BuildContext context) async {
    try {
      await PlayedDatabase.instance.clearAllSeekPositions();
      // Delete temp dirs if they exist
      final tmpDir = await getTemporaryDirectory();
      if (tmpDir.existsSync()) {
        for (final entity in tmpDir.listSync()) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared ✅'),
        backgroundColor: AppColors.surface,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
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
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.borderOf(context),
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

/// Downloads sheet body — uses Consumer so it can watch settingsProvider
/// and persist maxConcurrentDownloads without a local StatefulBuilder.
class _DownloadsSheetBody extends StatefulWidget {
  final AppSettings s;
  final SettingsNotifier sn;
  const _DownloadsSheetBody({required this.s, required this.sn});

  @override
  State<_DownloadsSheetBody> createState() => _DownloadsSheetBodyState();
}

class _DownloadsSheetBodyState extends State<_DownloadsSheetBody> {
  String _downloadPath = 'Loading…';

  @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((dir) {
      if (mounted) setState(() => _downloadPath = dir.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Downloads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 4),
            const Divider(color: AppColors.border, height: 24),

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
                _downloadPath,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),

            const Divider(color: AppColors.border, height: 28),

            // Max concurrent tasks — persisted via settingsProvider
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
                final active = widget.s.maxConcurrentDownloads == n;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.sn.setMaxConcurrentDownloads(n);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: active ? AppColors.accent : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.black : AppColors.textPrimary,
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


