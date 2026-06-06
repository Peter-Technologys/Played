import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../settings_provider.dart';

/// Full settings screen with all app preferences.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

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
        title: const Text('Settings',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 18,
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Playback ───────────────────────────────────────
          _SectionHeader('Playback'),
          _ToggleTile(
            icon: Icons.restore_rounded,
            label: 'Auto-Resume',
            subtitle: 'Continue from where you left off',
            value: settings.autoResume,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setAutoResume(v),
          ),
          _ToggleTile(
            icon: Icons.battery_saver_rounded,
            label: 'Battery Saver by Default',
            subtitle: 'Start video in audio-only mode',
            value: settings.defaultBatterySaver,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setDefaultBatterySaver(v),
          ),

          const SizedBox(height: 24),

          // ── Privacy ───────────────────────────────────────
          _SectionHeader('Privacy & Security'),
          _ToggleTile(
            icon: Icons.lock_rounded,
            label: 'App Lock',
            subtitle: 'Require biometrics or PIN to open app',
            value: settings.appLockEnabled,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setAppLock(v),
          ),

          const SizedBox(height: 24),

          // ── Language ───────────────────────────────────────
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
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setLanguage(v),
          ),

          const SizedBox(height: 24),

          // ── Storage ───────────────────────────────────────
          _SectionHeader('Storage'),
          _ActionTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Clear Playback History',
            subtitle: 'Remove all recently played records',
            color: AppColors.error,
            onTap: () async {
              HapticFeedback.mediumImpact();
              // TODO: call PlayedDatabase.instance.clearHistory()
            },
          ),
          _ActionTile(
            icon: Icons.folder_open_rounded,
            label: 'Browse by Folder',
            subtitle: 'View files organized by directory',
            color: AppColors.accent,
            onTap: () {},
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
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_circle_filled_rounded,
                      color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLAYED',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk',
                          letterSpacing: 2,
                        )),
                    Text('Version 1.0.0 · Built for East Africa',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Shared Tiles ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
            fontFamily: 'SpaceGrotesk',
          )),
    );
  }
}

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
                Text(label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'SpaceGrotesk',
                    )),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

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
    final selected = options.firstWhere(
      (o) => o.$2 == value,
      orElse: () => options.first,
    );
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
            child: Text(label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'SpaceGrotesk',
                )),
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
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontFamily: 'SpaceGrotesk',
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
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
