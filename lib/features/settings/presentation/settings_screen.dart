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
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Support ──────────────────────────────────────────────────────
          _SectionHeader('Support'),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFFFC107), size: 20),
            ),
            title: const Text('Rate OTYA Player',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            subtitle: const Text('Tell us what you think',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                )),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () => RateUsSheet.show(context),
          ),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bug_report_rounded,
                  color: Colors.redAccent, size: 20),
            ),
            title: const Text('Report a Problem',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            subtitle: const Text('Something not working? Let us know',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                )),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () => ReportProblemSheet.show(context),
          ),

          // ── Legal ─────────────────────────────────────────────────────────
          _SectionHeader('Legal'),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.privacy_tip_rounded,
                  color: AppColors.accent, size: 20),
            ),
            title: const Text('Privacy Policy',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            subtitle: const Text('How we handle your data',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                )),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
            title: const Text('OTYA Player',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            subtitle: const Text('Version info and credits',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                )),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2, fontFamily: 'Inter',
        ),
      ),
    );
  }
}
