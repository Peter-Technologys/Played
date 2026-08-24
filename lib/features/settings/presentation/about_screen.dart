import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/update_service.dart';
import '../../../core/widgets/update_dialog.dart';

/// Standalone About screen — reached via /about route.
/// Shows app logo, version, description, and support links.
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
      if (mounted) {
        setState(() {
          _version = info.version;
          _build = info.buildNumber;
        });
      }
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
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'About OTYA Player',
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
          // ── App card ──────────────────────────────────────────────
          const SizedBox(height: 8),
          _AppCard(version: _version, buildNumber: _build),

          const SizedBox(height: 24),

          // ── Support & Links ───────────────────────────────────────
          _SectionHeader(label: 'Support & Links'),
          const SizedBox(height: 10),

          _GroupCard(children: [
            _NavTile(
              icon: Icons.language_rounded,
              label: 'Visit Website',
              subtitle: 'getotya.petersmartlink.com',
              color: AppColors.accent,
              onTap: () => context.push('/webview', extra: {
                'url': 'https://getotya.petersmartlink.com',
                'title': 'OTYA Player',
              }),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.system_update_outlined,
              label: 'Check for Updates',
              subtitle: 'Tap to check for a new version',
              color: AppColors.accent,
              onTap: () => _checkForUpdates(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.new_releases_outlined,
              label: "What's New",
              subtitle: 'See what changed in this version',
              color: AppColors.accentViolet,
              onTap: () => context.push('/whats-new'),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.email_outlined,
              label: 'Contact Support',
              subtitle: 'support@petersmartlink.com',
              color: AppColors.accent,
              onTap: () => _launchEmail(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.share_rounded,
              label: 'Share App',
              subtitle: 'Send OTYA Player to a friend',
              color: AppColors.accentGreen,
              onTap: () => _shareApp(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              subtitle: 'How we handle your data',
              color: AppColors.textSecondary,
              onTap: () => context.push('/privacy'),
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

          const SizedBox(height: 32),

          // ── Footer ────────────────────────────────────────────────
          Center(
            child: Text(
              _version.isEmpty
                  ? 'OTYA Player'
                  : 'OTYA Player v$_version',
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
              '© 2026 PeterSmartLink. All rights reserved.',
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
    messenger.showSnackBar(const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent),
          ),
          SizedBox(width: 12),
          Text('Checking for updates…'),
        ],
      ),
      duration: Duration(seconds: 30),
      backgroundColor: AppColors.surface,
    ));
    try {
      final info = await UpdateService.instance.checkForUpdate(force: true);
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      if (info == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('You have the latest version ✅'),
          backgroundColor: AppColors.surface,
        ));
      } else {
        await UpdateDialog.checkAndShow(context);
      }
    } catch (_) {
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not check. Make sure you have internet.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@petersmartlink.com',
      queryParameters: {'subject': 'OTYA Player Support'},
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
        'Download OTYA Player v${info.version} — free offline media player for Android:\n'
        'https://petersmartlink.com/download/otya-player',
        subject: 'OTYA Player',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ── App Card ──────────────────────────────────────────────────────────────

class _AppCard extends StatelessWidget {
  final String version;
  final String buildNumber;
  const _AppCard({required this.version, required this.buildNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentViolet],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 0,
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
            // Logo
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
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
            // Title
            const Text(
              'OTYA Player',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            // Tagline
            const Text(
              'Otya? Play. Your media, your rules.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            // Version
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                version.isEmpty
                    ? 'Loading...'
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
            // Support email
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
            // Description
            const Text(
              'A premium offline media player inspired by the Luganda word "Otya?". '
              'Play, organise, and share your local audio and video — no internet required.',
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
}

// ── Shared widgets ────────────────────────────────────────────────────────

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
      child: Column(children: children),
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
