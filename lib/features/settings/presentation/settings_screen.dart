import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGoogle = ref.watch(isGoogleSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final photoUrl = ref.watch(photoUrlProvider);

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
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Account section ──────────────────────────────
          const _SectionHeader(label: 'Account'),
          const SizedBox(height: 12),

          if (isGoogle) ...
            [
              _AccountCard(
                photoUrl: photoUrl,
                displayName: displayName,
                onSignOut: () => _confirmSignOut(context, ref),
              ).animate().fadeIn(duration: 300.ms),
            ]
          else ...
            [
              _GoogleSignInButton(
                onTap: () => _signInWithGoogle(context, ref),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 8),
              const Text(
                'Sign in to sync Pro status and playlists across your devices.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
            ],

          const SizedBox(height: 32),

          // ── About section ────────────────────────────────
          const _SectionHeader(label: 'About'),
          const SizedBox(height: 12),

          // App identity card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.accent.withValues(alpha: 0.05),
                  ),
                  child: const Text(
                    'PLAYED',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      fontFamily: 'Inter',
                      letterSpacing: 5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your media. Your rules.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.1.0 (build 2)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),
                const Text(
                  'A high-performance offline media player built for East Africa. '
                  'Play, organise, and share your videos and music — no internet required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.6,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 12),

          // Developer tile
          _SettingsTile(
            icon: Icons.business_rounded,
            label: 'Developer',
            trailing: const Text(
              'PeterSmart Technologies',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),

          // Contact / email tile
          _TappableTile(
            icon: Icons.email_outlined,
            label: 'Contact Support',
            subtitle: 'dev@petersmartlink.com',
            onTap: () => _launchEmail(context),
          ),
          const SizedBox(height: 8),

          // Privacy Policy tile
          _TappableTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _launchUrl(
              context,
              'https://app.petersmartlink.com/played/privacy',
            ),
          ),
          const SizedBox(height: 8),

          // Rate the app tile
          _TappableTile(
            icon: Icons.star_outline_rounded,
            label: 'Rate PLAYED',
            subtitle: 'Enjoying the app? Leave a review!',
            onTap: () => _launchUrl(
              context,
              'https://play.google.com/store/apps/details?id=com.petersmart.played',
            ),
          ),

          const SizedBox(height: 40),

          // Footer branding
          const Center(
            child: Text(
              'from PeterSmart Technologies',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontFamily: 'Inter',
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle(
      BuildContext context, WidgetRef ref) async {
    final user = await AuthService.instance.signInWithGoogle();
    if (user == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in cancelled or failed. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign out?',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your Pro status and playlists will no longer sync across devices. Local data is kept.',
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AuthService.instance.signOut();
            },
            child: const Text('Sign out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'dev@petersmartlink.com',
      queryParameters: {
        'subject': 'PLAYED App Support',
      },
    );
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open email app.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ── Account Card (signed in) ─────────────────────────────────

class _AccountCard extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final VoidCallback onSignOut;
  const _AccountCard(
      {this.photoUrl, this.displayName, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: ClipOval(
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _InitialsCircle(name: displayName),
                    )
                  : _InitialsCircle(name: displayName),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName ?? 'Google User',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Syncing across devices',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSignOut,
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  final String? name;
  const _InitialsCircle({this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    return Container(
      color: AppColors.accentViolet.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Google Sign-In Button ────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4285F4),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  const _SettingsTile(
      {required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _TappableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _TappableTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...
                    [
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
