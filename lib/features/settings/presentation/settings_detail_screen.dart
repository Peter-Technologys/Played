import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/custom_theme_manager.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/update_dialog.dart';
import '../../../shared/widgets/otya_logo.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../settings_provider.dart';

/// OTYA v1 preferences.
///
/// Settings are grouped by the user outcome they control. Only preferences
/// with a real runtime owner are shown; compatibility toggles that no longer
/// affect OTYA are intentionally omitted.
class SettingsDetailScreen extends ConsumerWidget {
  const SettingsDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return WallpaperScaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/myspace'),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          const _SettingsIntro(),
          const SizedBox(height: 26),
          const _SectionTitle(
            'Look & feel',
            'Make OTYA comfortable without changing how your media is stored.',
          ),
          _Card(children: [
            _NavTile(
              icon: Icons.palette_rounded,
              title: 'Appearance',
              subtitle: 'Light, dark, AMOLED, themes and seasonal artwork',
              onTap: () => context.push('/theme'),
            ),
            const _Line(),
            _NavTile(
              icon: Icons.wallpaper_rounded,
              title: 'Choose wallpaper',
              subtitle: 'Use a photo from this device behind OTYA surfaces',
              onTap: () => _chooseWallpaper(context),
            ),
            const _Line(),
            _NavTile(
              icon: Icons.hide_image_rounded,
              title: 'Use theme background',
              subtitle: 'Remove your custom wallpaper',
              onTap: () => _removeWallpaper(context),
            ),
          ]),
          const SizedBox(height: 26),
          const _SectionTitle(
            'Playback',
            'Defaults for local music and video. Player controls can still override them when needed.',
          ),
          _Card(children: [
            _SwitchTile(
              icon: Icons.history_rounded,
              title: 'Resume playback',
              subtitle: 'Continue from the last saved position',
              value: settings.autoResume,
              onChanged: notifier.setAutoResume,
            ),
            const _Line(),
            _SwitchTile(
              icon: Icons.picture_in_picture_alt_rounded,
              title: 'Automatic picture-in-picture',
              subtitle: 'Keep supported video visible when OTYA leaves the foreground',
              value: settings.autoPip,
              onChanged: notifier.setAutoPip,
            ),
            const _Line(),
            _SwitchTile(
              icon: Icons.screen_rotation_alt_rounded,
              title: 'Lock video orientation',
              subtitle: 'Keep the selected orientation while video is playing',
              value: settings.orientationLocked,
              onChanged: notifier.setOrientationLocked,
            ),
            const _Line(),
            _SwitchTile(
              icon: Icons.skip_next_rounded,
              title: 'Continuous playback',
              subtitle: 'Continue to the next item in the current queue',
              value: settings.continuousPlayback,
              onChanged: notifier.setContinuousPlayback,
            ),
            const _Line(),
            _SwitchTile(
              icon: Icons.closed_caption_rounded,
              title: 'Auto-load subtitles',
              subtitle: 'Use compatible subtitle tracks when available',
              value: settings.autoLoadSubtitles,
              onChanged: notifier.setAutoLoadSubtitles,
            ),
            const _Line(),
            _SwitchTile(
              icon: Icons.phone_in_talk_rounded,
              title: 'Pause during calls',
              subtitle: 'Respect Android call state and audio focus',
              value: settings.pauseDuringCalls,
              onChanged: notifier.setPauseDuringCalls,
            ),
            const _Line(),
            _SpeedTile(
              value: settings.playbackSpeed,
              onChanged: notifier.setPlaybackSpeed,
            ),
          ]),
          const SizedBox(height: 26),
          const _SectionTitle(
            'Privacy & device',
            'Controls that affect this phone, local history and protected media.',
          ),
          _Card(children: [
            _NavTile(
              icon: Icons.lock_rounded,
              title: 'Private',
              subtitle: 'Protected local media and device authentication',
              onTap: () => context.push('/vault'),
            ),
            const _Line(),
            _SwitchTile(
              icon: Icons.phonelink_lock_rounded,
              title: 'App Lock',
              subtitle:
                  'Require Android screen lock, fingerprint or face after OTYA leaves the foreground',
              value: settings.appLockEnabled,
              onChanged: notifier.setAppLock,
            ),
            const _Line(),
            _SwitchTile(
              icon: Icons.manage_search_rounded,
              title: 'Search history',
              subtitle: 'Remember recent OTYA searches only on this device',
              value: settings.searchHistory,
              onChanged: notifier.setSearchHistory,
            ),
            const _Line(),
            _NavTile(
              icon: Icons.notifications_active_rounded,
              title: 'Notifications',
              subtitle: 'Playback controls, completed tasks and OTYA updates',
              onTap: () async {
                HapticFeedback.selectionClick();
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? 'Notifications are enabled.'
                          : 'Notification permission was not granted.',
                    ),
                  ),
                );
              },
            ),
            const _Line(),
            _NavTile(
              icon: Icons.settings_applications_rounded,
              title: 'Android permissions',
              subtitle: 'Review media, notification and phone permissions',
              onTap: () => openAppSettings(),
            ),
            const _Line(),
            _NavTile(
              icon: Icons.storage_rounded,
              title: 'Storage',
              subtitle: 'Understand OTYA media and device storage usage',
              onTap: () => context.push('/settings/storage'),
            ),
          ]),
          const SizedBox(height: 26),
          const _SectionTitle(
            'Product & support',
            'Updates, Next, privacy information and product details.',
          ),
          _Card(children: [
            _NavTile(
              icon: Icons.system_update_rounded,
              title: 'Check for updates',
              subtitle: 'Check the canonical OTYA release service',
              onTap: () async {
                HapticFeedback.selectionClick();
                await UpdateDialog.checkAndShow(context, forceCheck: true);
              },
            ),
            const _Line(),
            _NavTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Next',
              subtitle: 'Ask for help with OTYA or a general question',
              onTap: () => context.push('/support'),
            ),
            const _Line(),
            _NavTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'How OTYA handles local, account and service data',
              onTap: () => context.push('/privacy'),
            ),
            const _Line(),
            _NavTile(
              icon: Icons.info_outline_rounded,
              title: 'About OTYA',
              subtitle: 'Version, product information and legal links',
              onTap: () => context.push('/about'),
            ),
          ]),
        ],
      ),
    );
  }

  static Future<void> _chooseWallpaper(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;
      await CustomThemeManager.instance.setWallpaper(picked.path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper updated.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTYA could not use that image.')),
      );
    }
  }

  static Future<void> _removeWallpaper(BuildContext context) async {
    await CustomThemeManager.instance.clearWallpaper();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme background restored.')),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OtyaMark(size: 44),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make OTYA yours',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.35,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Playback, privacy and appearance stay understandable and reversible. Account data is managed separately in OTYA Account.',
                    style: TextStyle(
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.description);
  final String text;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(children: children),
      );
}

class _Line extends StatelessWidget {
  const _Line();
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 68,
        color: AppColors.borderOf(context),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        leading: _TileIcon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, maxLines: 2),
        trailing: const Icon(Icons.chevron_right_rounded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: (next) {
          HapticFeedback.selectionClick();
          onChanged(next);
        },
        secondary: _TileIcon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      );
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 21, color: AppColors.accent),
      );
}

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  static const speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const _TileIcon(Icons.speed_rounded),
        title: const Text(
          'Default playback speed',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Used when a player starts a new session'),
        trailing: DropdownButton<double>(
          value: speeds.contains(value) ? value : 1.0,
          underline: const SizedBox.shrink(),
          items: speeds
              .map(
                (speed) => DropdownMenuItem(
                  value: speed,
                  child: Text('$speed×'),
                ),
              )
              .toList(growable: false),
          onChanged: (next) {
            if (next == null) return;
            HapticFeedback.selectionClick();
            onChanged(next);
          },
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      );
}
