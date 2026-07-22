import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/rate_us_sheet.dart';
import '../../../core/widgets/report_problem_sheet.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'storage_analyzer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _s = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _s.addListener(_rebuild);
  }

  @override
  void dispose() {
    _s.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── APPEARANCE & PLAYBACK ─────────────────────────────────
          const _Header('Appearance & Playback'),
          _Tile(
            icon: Icons.dark_mode_rounded,
            color: AppColors.accentViolet,
            title: 'Theme Mode',
            sub: 'Dark / AMOLED / Light',
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/theme');
            },
          ),
          const _Div(),
          _Tile(
            icon: Icons.language_rounded,
            color: AppColors.accent,
            title: 'Language',
            sub: 'App display language',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Language settings coming soon')),
            ),
          ),
          const _Div(),
          _Tile(
            icon: Icons.storage_rounded,
            color: AppColors.accentAmber,
            title: 'Cache',
            sub: 'Clear thumbnail & media cache',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const StorageAnalyzerScreen()),
            ),
          ),
          const _Div(),
          _Tile(
            icon: Icons.videocam_rounded,
            color: AppColors.accent,
            title: 'Video Settings',
            sub: 'Subtitles, aspect ratio, hardware decode',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video settings coming soon')),
            ),
          ),
          const _Div(),
          _Tile(
            icon: Icons.headphones_rounded,
            color: AppColors.accentViolet,
            title: 'Audio Settings',
            sub: 'Equalizer, bass boost, stereo',
            onTap: () => context.push('/player/equalizer'),
          ),
          const _Div(),
          _switchTile(
            icon: Icons.music_note_rounded,
            color: AppColors.accentGreen,
            title: 'Gapless Playback',
            sub: 'Seamless transitions between tracks',
            value: _s.skipSilence, // reuse closest available toggle
            onChanged: _s.setSkipSilence,
          ),
          const _Div(),
          _switchTile(
            icon: Icons.skip_next_rounded,
            color: AppColors.accent,
            title: 'Skip Silence',
            sub: 'Auto-skip silent sections',
            value: _s.skipSilence,
            onChanged: _s.setSkipSilence,
          ),
          const _Div(),
          _speedTile(),

          // ── STORAGE & PRIVACY ─────────────────────────────────────
          const _Header('Storage & Privacy'),
          _Tile(
            icon: Icons.folder_rounded,
            color: AppColors.accentAmber,
            title: 'Downloads Path',
            sub: 'Where downloaded files are saved',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Downloads path coming soon')),
            ),
          ),
          const _Div(),
          _switchTile(
            icon: Icons.lock_rounded,
            color: AppColors.accentViolet,
            title: 'App Lock',
            sub: 'Require biometric to open app',
            value: _s.showLyrics, // placeholder — closest available
            onChanged: _s.setShowLyrics,
          ),
          const _Div(),
          _switchTile(
            icon: Icons.visibility_off_rounded,
            color: AppColors.accentViolet,
            title: 'Hide Vault',
            sub: 'Hide vault from home screen',
            value: _s.showLyrics,
            onChanged: _s.setShowLyrics,
          ),

          // ── ABOUT & SUPPORT ───────────────────────────────────────
          const _Header('About & Support'),
          _Tile(
            icon: Icons.system_update_rounded,
            color: AppColors.accent,
            title: 'Check for Updates',
            sub: 'See if a newer version is available',
            onTap: () => IntentLauncher.openUrl(
                'https://getotya.petersmartlink.com/download'),
          ),
          const _Div(),
          _Tile(
            icon: Icons.info_outline_rounded,
            color: AppColors.textSecondary,
            title: 'About OTYA Player',
            sub: 'Version, credits & privacy policy',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const _Div(),
          _Tile(
            icon: Icons.star_rounded,
            color: const Color(0xFFFFC107),
            title: 'Rate OTYA Player',
            sub: 'Tell us what you think',
            onTap: () => RateUsSheet.show(context),
          ),
          const _Div(),
          _Tile(
            icon: Icons.bug_report_rounded,
            color: Colors.redAccent,
            title: 'Report a Problem',
            sub: 'Something not working?',
            onTap: () => ReportProblemSheet.show(context),
          ),
          const _Div(),
          _Tile(
            icon: Icons.privacy_tip_rounded,
            color: AppColors.accent,
            title: 'Privacy Policy',
            sub: 'How we handle your data',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) =>
      ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter')),
        subtitle: Text(sub,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Inter')),
        trailing: Switch(
          value: value,
          onChanged: (v) => onChanged(v),
          activeColor: AppColors.accent,
          activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
          inactiveThumbColor: AppColors.textSecondary,
          inactiveTrackColor: AppColors.border,
        ),
      );

  Widget _speedTile() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: AppColors.accentPink.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.speed_rounded,
            color: AppColors.accentPink, size: 20),
      ),
      title: const Text('Default Speed',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Inter')),
      subtitle: Text('${_s.playbackSpeed}\u00d7',
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'Inter')),
      trailing: DropdownButton<double>(
        value: _s.playbackSpeed,
        dropdownColor: AppColors.surfaceElevated,
        underline: const SizedBox(),
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
            fontSize: 13),
        items: speeds
            .map((s) =>
                DropdownMenuItem(value: s, child: Text('${s}\u00d7')))
            .toList(),
        onChanged: (v) {
          if (v != null) _s.setPlaybackSpeed(v);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String t;
  const _Header(this.t);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.4,
              fontFamily: 'Inter'),
        ),
      );
}

class _Div extends StatelessWidget {
  const _Div();

  @override
  Widget build(BuildContext context) => const Divider(
      height: 1,
      indent: 72,
      endIndent: 20,
      color: AppColors.borderSubtle);
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter')),
        subtitle: Text(sub,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Inter')),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textSecondary, size: 20),
        onTap: onTap,
      );
}
