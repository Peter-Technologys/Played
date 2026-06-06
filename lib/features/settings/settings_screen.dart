import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Appearance ────────────────────────────────────
          _SectionHeader('Appearance'),
          _SegmentTile(
            icon: Icons.palette_rounded,
            label: 'Theme',
            options: const ['Dark', 'AMOLED', 'Light'],
            selectedIndex: settings.themeMode.index,
            onChanged: (i) =>
                notifier.setThemeMode(AppThemeMode.values[i]),
          ),
          const SizedBox(height: 24),

          // ── Playback ──────────────────────────────────────
          _SectionHeader('Playback'),
          _ToggleTile(
            icon: Icons.restore_rounded,
            label: 'Auto-Resume',
            subtitle: 'Continue from where you left off',
            value: settings.autoResume,
            onChanged: notifier.setAutoResume,
          ),
          _ToggleTile(
            icon: Icons.battery_saver_rounded,
            label: 'Battery Saver by Default',
            subtitle: 'Start video in audio-only mode',
            value: settings.defaultBatterySaver,
            onChanged: notifier.setDefaultBatterySaver,
          ),
          _ToggleTile(
            icon: Icons.shuffle_rounded,
            label: 'Shuffle',
            subtitle: 'Play files in random order',
            value: settings.shuffle,
            onChanged: notifier.setShuffle,
          ),
          _SelectTile(
            icon: Icons.repeat_rounded,
            label: 'Repeat Mode',
            value: settings.repeatMode.name,
            options: const [
              ('Off', 'off'),
              ('Repeat One', 'one'),
              ('Repeat All', 'all'),
            ],
            onChanged: (v) => notifier.setRepeatMode(
                RepeatMode.values.firstWhere((e) => e.name == v)),
          ),
          _SliderTile(
            icon: Icons.blur_on_rounded,
            label: 'Crossfade',
            subtitle:
                '${settings.crossfadeDuration.toStringAsFixed(1)}s between tracks',
            value: settings.crossfadeDuration,
            min: 0,
            max: 5,
            onChanged: notifier.setCrossfade,
          ),
          _ToggleTile(
            icon: Icons.volume_off_rounded,
            label: 'Skip Silence',
            subtitle: 'Auto-skip silent sections',
            value: settings.skipSilence,
            onChanged: notifier.setSkipSilence,
          ),
          _ToggleTile(
            icon: Icons.queue_music_rounded,
            label: 'Gapless Playback',
            subtitle: 'No pause between tracks',
            value: settings.gaplessPlayback,
            onChanged: notifier.setGaplessPlayback,
          ),
          const SizedBox(height: 24),

          // ── Notifications ─────────────────────────────────
          _SectionHeader('Notifications'),
          _ToggleTile(
            icon: Icons.notifications_rounded,
            label: 'Now Playing Notification',
            subtitle: 'Show media controls in notification bar',
            value: settings.nowPlayingNotification,
            onChanged: notifier.setNowPlayingNotification,
          ),
          const SizedBox(height: 24),

          // ── Private Vault ─────────────────────────────────
          _SectionHeader('Private Vault'),
          _ActionTile(
            icon: Icons.lock_rounded,
            label: 'Open Vault',
            subtitle: 'Access your encrypted private media',
            color: AppColors.accentViolet,
            onTap: () => context.push('/vault'),
          ),
          _ToggleTile(
            icon: Icons.visibility_off_rounded,
            label: 'Hide Vault from Recents',
            subtitle: 'Vault won\'t appear in app switcher',
            value: settings.hideVaultFromRecents,
            onChanged: notifier.setHideVaultFromRecents,
          ),
          const SizedBox(height: 24),

          // ── Privacy & Security ────────────────────────────
          _SectionHeader('Privacy & Security'),
          _ToggleTile(
            icon: Icons.fingerprint_rounded,
            label: 'App Lock',
            subtitle: 'Require biometrics or PIN to open app',
            value: settings.appLockEnabled,
            onChanged: notifier.setAppLock,
          ),
          const SizedBox(height: 24),

          // ── Storage ───────────────────────────────────────
          _SectionHeader('Storage'),
          _ActionTile(
            icon: Icons.folder_open_rounded,
            label: 'Scan Folders',
            subtitle: settings.scanFolders.isEmpty
                ? 'Scanning all device storage'
                : '${settings.scanFolders.length} folder(s) selected',
            color: AppColors.accent,
            onTap: () {
              // TODO: open folder picker
              HapticFeedback.lightImpact();
            },
          ),
          _ActionTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Clear Playback History',
            subtitle: 'Remove all recently played records',
            color: AppColors.error,
            onTap: () async {
              HapticFeedback.mediumImpact();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Clear History?',
                      style: TextStyle(color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk')),
                  content: const Text(
                      'This will remove all recently played records.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textSecondary))),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                      child: const Text('Clear',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await PlayedDatabase.instance.clearHistory();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Playback history cleared')));
                }
              }
            },
          ),
          _ActionTile(
            icon: Icons.cleaning_services_rounded,
            label: 'Clear Stem Cache',
            subtitle: 'Free up space used by Studio splits',
            color: AppColors.warning,
            onTap: () async {
              HapticFeedback.mediumImpact();
              await PlayedDatabase.instance.invalidateShelfCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stem cache cleared')));
              }
            },
          ),
          const SizedBox(height: 24),

          // ── Language ──────────────────────────────────────
          _SectionHeader('Language'),
          _SelectTile(
            icon: Icons.language_rounded,
            label: 'App Language',
            value: settings.language,
            options: const [
              ('English', 'en'),
              ('Luganda', 'lg'),
              ('Kiswahili', 'sw'),
            ],
            onChanged: notifier.setLanguage,
          ),
          const SizedBox(height: 24),

          // ── About ─────────────────────────────────────────
          _SectionHeader('About'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_circle_filled_rounded,
                      color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAYED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'SpaceGrotesk',
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'Version 1.0.0 · PeterSmart Technologies',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                    Text(
                      'Mbirizi, Lwengo District, Uganda',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.star_rounded,
            label: 'Rate Played',
            subtitle: 'Leave a review on the Play Store',
            color: AppColors.warning,
            onTap: () async {
              HapticFeedback.lightImpact();
              final uri = Uri.parse(
                  'https://play.google.com/store/apps/details?id=com.petersmart.played');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          _ActionTile(
            icon: Icons.bug_report_rounded,
            label: 'Send Feedback',
            subtitle: 'Report a bug or suggest a feature',
            color: AppColors.accent,
            onTap: () async {
              HapticFeedback.lightImpact();
              final uri = Uri.parse(
                  'mailto:support@petersmartlink.com?subject=Feedback%20%E2%80%94%20Played%20App');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          _ActionTile(
            icon: Icons.policy_rounded,
            label: 'Privacy Policy',
            subtitle: 'How we handle your data',
            color: AppColors.textSecondary,
            onTap: () async {
              HapticFeedback.lightImpact();
              final uri = Uri.parse('https://petersmartlink.com/privacy');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
          fontFamily: 'SpaceGrotesk',
        ),
      ),
    );
  }
}

// ── Toggle Tile ────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

// ── Slider Tile ────────────────────────────────────────────

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  const _SliderTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.12),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Select Tile ────────────────────────────────────────────

class _SelectTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  const _SelectTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            dropdownColor: AppColors.surface,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
                color: AppColors.accent,
                fontFamily: 'SpaceGrotesk',
                fontSize: 13),
            items: options
                .map((o) => DropdownMenuItem(
                      value: o.$2,
                      child: Text(o.$1),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                HapticFeedback.selectionClick();
                onChanged(v);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Segment Tile ───────────────────────────────────────────

class _SegmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _SegmentTile({
    required this.icon,
    required this.label,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: List.generate(options.length, (i) {
                final active = i == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        options[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.black
                              : AppColors.textSecondary,
                          fontFamily: 'SpaceGrotesk',
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Tile ────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
