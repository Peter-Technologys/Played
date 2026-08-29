import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/config/environment.dart';
import '../../../core/services/update_service.dart';
import '../../../core/widgets/rate_us_sheet.dart';
import '../../../core/widgets/update_dialog.dart';

/// Help & About stays useful even when online support is unavailable.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _build = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _build = info.buildNumber;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Help & About',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const SizedBox(height: 8),
          _AppCard(version: _version, buildNumber: _build),
          const SizedBox(height: 24),
          const _SectionHeader(label: 'Support'),
          const SizedBox(height: 10),
          _GroupCard(
            children: [
              _NavTile(
                icon: Icons.auto_awesome_rounded,
                label: 'Ask OTYA',
                subtitle: 'Help with OTYA features, playback and problems',
                color: AppColors.accentViolet,
                onTap: () => context.push('/support'),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.bug_report_outlined,
                label: 'Report a problem',
                subtitle: 'Send a problem report to OTYA Support',
                color: AppColors.accentAmber,
                onTap: () => _launchEmail(
                  context,
                  subject: 'OTYA Player Problem Report',
                ),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.email_outlined,
                label: 'Email support',
                subtitle: 'support@petersmartlink.com',
                color: AppColors.accent,
                onTap: () => _launchEmail(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(label: 'About'),
          const SizedBox(height: 10),
          _GroupCard(
            children: [
              _NavTile(
                icon: Icons.language_rounded,
                label: 'OTYA website',
                subtitle: 'Official product website',
                color: AppColors.accent,
                onTap: () => context.push(
                  '/webview',
                  extra: {'url': Environment.websiteUrl, 'title': 'OTYA'},
                ),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.description_outlined,
                label: 'Help & docs',
                subtitle: 'Guides, account, privacy and support',
                color: AppColors.accentViolet,
                onTap: () => context.push(
                  '/webview',
                  extra: {'url': Environment.docsUrl, 'title': 'OTYA Docs'},
                ),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.system_update_outlined,
                label: 'Check for updates',
                subtitle: 'Check for a newer OTYA version',
                color: AppColors.accent,
                onTap: () => _checkForUpdates(context),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.new_releases_outlined,
                label: 'What’s new',
                subtitle: 'See what changed in this version',
                color: AppColors.accentViolet,
                onTap: () => context.push('/whats-new'),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.share_rounded,
                label: 'Share OTYA',
                subtitle: 'Send OTYA to a friend',
                color: AppColors.accentGreen,
                onTap: () => _shareApp(context),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy',
                subtitle: 'How OTYA handles your data',
                color: AppColors.textSecondary,
                onTap: () => context.push('/privacy'),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.star_outline_rounded,
                label: 'Rate OTYA',
                subtitle: 'Send your rating directly to OTYA',
                color: AppColors.accentAmber,
                onTap: () => RateUsSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              _version.isEmpty ? 'OTYA' : 'OTYA v$_version',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '© 2026 PeterSmart Link',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            SizedBox(width: 12),
            Text('Checking for updates…'),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: AppColors.surface,
      ),
    );
    try {
      final info = await UpdateService.instance.checkForUpdate(force: true);
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      if (info == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('You have the latest version.'),
            backgroundColor: AppColors.surface,
          ),
        );
      } else {
        await UpdateDialog.checkAndShow(context);
      }
    } catch (_) {
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not check. Make sure you have internet.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _launchEmail(
    BuildContext context, {
    String subject = 'OTYA Player Support',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@petersmartlink.com',
      queryParameters: {'subject': subject},
    );
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      await Share.share(
        'Download OTYA v${info.version} — an offline-first media player for Android:\n${Environment.downloadPageUrl}',
        subject: 'OTYA',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open sharing right now.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _AppCard extends StatelessWidget {
  final String version;
  final String buildNumber;
  const _AppCard({required this.version, required this.buildNumber});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentViolet],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.18),
              blurRadius: 24,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icons/play_store_512.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.accentViolet],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'OTYA',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Video, music and sharing in one place.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  version.isEmpty
                      ? 'Loading…'
                      : 'Version $version (build $buildNumber)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'support@petersmartlink.com',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 20),
              const Text(
                'Play, organise and share local audio and video with an offline-first experience. Online help and account features are optional.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(
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

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: AppColors.borderOf(context),
        indent: 16,
        endIndent: 16,
      );
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
  Widget build(BuildContext context) => ListTile(
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Inter',
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary,
          size: 18,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
}
