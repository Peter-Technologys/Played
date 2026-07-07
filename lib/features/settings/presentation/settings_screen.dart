import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/widgets/rate_us_sheet.dart';
import '../../../core/widgets/report_problem_sheet.dart';
import 'privacy_policy_screen.dart';
import 'storage_analyzer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _s    = SettingsService.instance;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = _s.profileName;
    _s.addListener(_rebuild);
  }

  @override
  void dispose() { _s.removeListener(_rebuild); _name.dispose(); super.dispose(); }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Inter')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _Header('Profile'),
          _profileTile(),
          _Header('Playback'),
          _switchTile(icon: Icons.skip_next_rounded, color: AppColors.accent,
              title: 'Skip Silence', sub: 'Auto-skip silent sections',
              value: _s.skipSilence, onChanged: _s.setSkipSilence),
          const _Div(),
          _switchTile(icon: Icons.lyrics_rounded, color: AppColors.accentViolet,
              title: 'Show Lyrics', sub: 'Display lyrics when available',
              value: _s.showLyrics, onChanged: _s.setShowLyrics),
          const _Div(),
          _speedTile(),
          _Header('Storage'),
          _Tile(icon: Icons.storage_rounded, color: AppColors.accentAmber,
              title: 'Storage Analyzer', sub: 'View usage and clear cache',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StorageAnalyzerScreen()))),
          _Header('Support'),
          _Tile(icon: Icons.star_rounded, color: const Color(0xFFFFC107),
              title: 'Rate OTYA Player', sub: 'Tell us what you think',
              onTap: () => RateUsSheet.show(context)),
          const _Div(),
          _Tile(icon: Icons.bug_report_rounded, color: Colors.redAccent,
              title: 'Report a Problem', sub: 'Something not working?',
              onTap: () => ReportProblemSheet.show(context)),
          const _Div(),
          _Tile(icon: Icons.language_rounded, color: AppColors.accent,
              title: 'Visit Website', sub: 'petersmartlink.com',
              onTap: () => IntentLauncher.openUrl('https://petersmartlink.com')),
          const _Div(),
          _Tile(icon: Icons.star_rate_rounded, color: const Color(0xFFFFC107),
              title: 'Rate on Play Store', sub: 'Support us with 5 stars',
              onTap: () => IntentLauncher.openPlayStore('com.otyaplayer.app')),
          const _Div(),
          _Tile(icon: Icons.email_rounded, color: AppColors.accentGreen,
              title: 'Contact Support', sub: 'support@petersmartlink.com',
              onTap: () => IntentLauncher.openEmail(
                  'support@petersmartlink.com', subject: 'OTYA Player Support')),
          _Header('Legal'),
          _Tile(icon: Icons.privacy_tip_rounded, color: AppColors.accent,
              title: 'Privacy Policy', sub: 'How we handle your data',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
          const _Div(),
          _Tile(icon: Icons.policy_rounded, color: AppColors.textSecondary,
              title: 'Terms of Service', sub: 'Read our terms',
              onTap: () => IntentLauncher.openUrl('https://petersmartlink.com/terms')),
          _Header('About'),
          _Tile(icon: Icons.info_outline_rounded, color: AppColors.textSecondary,
              title: 'OTYA Player', sub: 'Version info and credits',
              onTap: () => showAboutDialog(context: context,
                  applicationName: 'OTYA Player',
                  applicationLegalese: '\u00a9 2026 PeterSmart Link')),
        ],
      ),
    );
  }

  Widget _profileTile() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 48, height: 48,
          decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.person_rounded, color: AppColors.accent, size: 24)),
      const SizedBox(width: 14),
      Expanded(child: TextField(
        controller: _name,
        style: const TextStyle(color: AppColors.textPrimary,
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontFamily: 'Inter'),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onSubmitted: _s.setProfileName,
        textInputAction: TextInputAction.done,
      )),
      IconButton(
        icon: const Icon(Icons.check_rounded, color: AppColors.accent, size: 20),
        onPressed: () => _s.setProfileName(_name.text.trim()),
      ),
    ]),
  );

  Widget _switchTile({
    required IconData icon, required Color color,
    required String title, required String sub,
    required bool value, required Future<void> Function(bool) onChanged,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    leading: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20)),
    title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary, fontFamily: 'Inter')),
    subtitle: Text(sub, style: const TextStyle(fontSize: 12,
        color: AppColors.textSecondary, fontFamily: 'Inter')),
    trailing: Switch(
      value: value, onChanged: (v) => onChanged(v),
      activeColor: AppColors.accent,
      activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.border,
    ),
  );

  Widget _speedTile() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(
              color: AppColors.accentPink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.speed_rounded, color: AppColors.accentPink, size: 20)),
      title: const Text('Default Speed', style: TextStyle(fontSize: 14,
          fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Inter')),
      subtitle: Text('${_s.playbackSpeed}\u00d7', style: const TextStyle(
          fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Inter')),
      trailing: DropdownButton<double>(
        value: _s.playbackSpeed,
        dropdownColor: AppColors.surfaceElevated,
        underline: const SizedBox(),
        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter', fontSize: 13),
        items: speeds.map((s) => DropdownMenuItem(value: s, child: Text('${s}\u00d7'))).toList(),
        onChanged: (v) { if (v != null) _s.setPlaybackSpeed(v); },
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
    child: Text(t.toUpperCase(), style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.textSecondary, letterSpacing: 1.4, fontFamily: 'Inter')),
  );
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 72, endIndent: 20, color: AppColors.borderSubtle);
}

class _Tile extends StatelessWidget {
  final IconData icon; final Color color;
  final String title, sub; final VoidCallback onTap;
  const _Tile({required this.icon, required this.color,
      required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20)),
    title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary, fontFamily: 'Inter')),
    subtitle: Text(sub, style: const TextStyle(fontSize: 12,
        color: AppColors.textSecondary, fontFamily: 'Inter')),
    trailing: const Icon(Icons.chevron_right_rounded,
        color: AppColors.textSecondary, size: 20),
    onTap: onTap,
  );
}


/// Main Settings screen for OTYA Player.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
            fontSize: 20, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Inter',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Support ──────────────────────────────────────────────────────
          _SectionHeader('Support'),
          _SettingsTile(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFFFC107),
            title: 'Rate OTYA Player',
            subtitle: 'Tell us what you think',
            onTap: () => RateUsSheet.show(context),
          ),
          const _Divider(),
          _SettingsTile(
            icon: Icons.bug_report_rounded,
            iconColor: Colors.redAccent,
            title: 'Report a Problem',
            subtitle: 'Something not working? Let us know',
            onTap: () => ReportProblemSheet.show(context),
          ),

          // ── Legal ─────────────────────────────────────────────────────────
          _SectionHeader('Legal'),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            iconColor: AppColors.accent,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.textSecondary,
            title: 'OTYA Player',
            subtitle: 'Version info and credits',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'OTYA Player',
              applicationLegalese: '© 2026 PeterSmart Link',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.4, fontFamily: 'Inter',
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(
    height: 1, indent: 72, endIndent: 20,
    color: AppColors.borderSubtle,
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary, fontFamily: 'Inter',
          )),
      subtitle: Text(subtitle,
          style: const TextStyle(
            fontSize: 12, color: AppColors.textSecondary,
            fontFamily: 'Inter',
          )),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary, size: 20),
      onTap: onTap,
    );
  }
}
