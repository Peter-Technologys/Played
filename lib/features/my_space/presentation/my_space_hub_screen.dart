import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/services/auth_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────
const _kCard   = Color(0xFF1B1E2B);
const _kBorder = Color(0xFF2A2F45);
const _kCyan   = Color(0xFF00D2FF);

// ── Google Sign-In state ──────────────────────────────────────────────────

final _googleUserProvider =
    StateProvider<GoogleSignInAccount?>((ref) => null);

/// The canonical MY SPACE screen.
/// Section 1: Google Sign-In banner
/// Section 2: 3×3 Quick Tools grid
/// Section 3: Settings navigation list
class MySpaceHubScreen extends ConsumerStatefulWidget {
  const MySpaceHubScreen({super.key});

  @override
  ConsumerState<MySpaceHubScreen> createState() => _MySpaceHubScreenState();
}

class _MySpaceHubScreenState extends ConsumerState<MySpaceHubScreen> {
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      if (mounted) {
        ref.read(_googleUserProvider.notifier).state = account;
      }
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.signOut();
    ref.read(_googleUserProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final googleUser = ref.watch(_googleUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Screen title ─────────────────────────────────────
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet],
                ).createShader(b),
                child: const Text(
                  'My Space',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Inter',
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your account, tools & settings',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),

              const SizedBox(height: 20),

              // ── Section 1: Google Sign-In Banner ─────────────────
              _GoogleSignInBanner(
                user: googleUser,
                onSignIn: _handleSignIn,
                onSignOut: _handleSignOut,
              ),

              const SizedBox(height: 24),

              // ── Section 2: Quick Tools Grid ───────────────────────
              _SectionLabel(label: 'Quick Tools'),
              const SizedBox(height: 12),
              _QuickToolsGrid(),

              const SizedBox(height: 24),

              // ── Section 3: Settings Navigation List ──────────────
              _SectionLabel(label: 'Settings & Support'),
              const SizedBox(height: 8),
              _SettingsNavList(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section 1: Google Sign-In Banner ─────────────────────────────────────

class _GoogleSignInBanner extends StatelessWidget {
  final GoogleSignInAccount? user;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  const _GoogleSignInBanner({
    required this.user,
    required this.onSignIn,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: user != null
          ? _SignedInRow(user: user!, onSignOut: onSignOut)
          : _SignInRow(onSignIn: onSignIn),
    );
  }
}

class _SignedInRow extends StatelessWidget {
  final GoogleSignInAccount user;
  final VoidCallback onSignOut;
  const _SignedInRow({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 26,
          backgroundImage: user.photoUrl != null
              ? NetworkImage(user.photoUrl!)
              : null,
          backgroundColor: AppColors.accentViolet.withValues(alpha: 0.3),
          child: user.photoUrl == null
              ? Text(
                  (user.displayName?.isNotEmpty == true)
                      ? user.displayName![0].toUpperCase()
                      : 'G',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? 'Google User',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Sync your media across devices',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSignOut,
          child: const Text(
            'Sign out',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SignInRow extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInRow({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSignIn,
      child: Row(
        children: [
          // Google 'G' icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sync your media across devices',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ── Section 2: Quick Tools Grid ───────────────────────────────────────────

class _QuickToolsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = [
      _ToolItem(
        icon: Icons.lock_rounded,
        label: 'Vault',
        onTap: () => context.push('/vault'),
      ),
      _ToolItem(
        icon: Icons.wifi_tethering_rounded,
        label: 'Air-Drop',
        onTap: () => context.push('/airdrop'),
      ),
      _ToolItem(
        icon: Icons.audio_file_rounded,
        label: 'MP3 Converter',
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coming Soon')),
        ),
      ),
      _ToolItem(
        icon: Icons.content_cut_rounded,
        label: 'Video Trimmer',
        onTap: () => context.push('/tools/whatsapp'),
      ),
      _ToolItem(
        icon: Icons.palette_rounded,
        label: 'Theme Manager',
        onTap: () => context.push('/theme'),
      ),
      _ToolItem(
        icon: Icons.equalizer_rounded,
        label: 'Equalizer',
        onTap: () => context.push('/player/equalizer'),
      ),
      _ToolItem(
        icon: Icons.history_rounded,
        label: 'History',
        onTap: () => context.push('/history'),
      ),
      _ToolItem(
        icon: Icons.cleaning_services_rounded,
        label: 'Storage Cleaner',
        onTap: () => context.push('/settings'),
      ),
      _ToolItem(
        icon: Icons.delete_outline_rounded,
        label: 'Recycle Bin',
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coming Soon')),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) => _ToolCard(item: tools[i]),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _ToolCard extends StatelessWidget {
  final _ToolItem item;
  const _ToolCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        item.onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: _kCyan, size: 26),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section 3: Settings Navigation List ──────────────────────────────────

class _SettingsNavList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.settings_rounded,
                color: AppColors.accent, size: 22),
            title: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/settings');
            },
          ),
          const Divider(height: 1, color: _kBorder, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded,
                color: AppColors.accentViolet, size: 22),
            title: const Text(
              'Help & Feedback',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            subtitle: const Text(
              'support@petersmartlink.com',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () async {
              HapticFeedback.selectionClick();
              final uri = Uri(
                scheme: 'mailto',
                path: 'support@petersmartlink.com',
                queryParameters: {'subject': 'OTYA Player Feedback'},
              );
              await launchUrl(uri);
            },
          ),
          const Divider(height: 1, color: _kBorder, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded,
                color: AppColors.textSecondary, size: 22),
            title: const Text(
              'About OTYA Player',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/about');
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

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
