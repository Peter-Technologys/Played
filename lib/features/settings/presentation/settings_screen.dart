import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/rate_us_sheet.dart';
import '../../../core/widgets/report_problem_sheet.dart';
import 'privacy_policy_screen.dart';

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
