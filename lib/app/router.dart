import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/my_space/presentation/my_space_screen.dart';
import '../features/my_space/presentation/folder_browser_screen.dart';
import '../features/air_drop/presentation/air_drop_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/player/presentation/audio_player_screen.dart';
import '../features/player/presentation/equalizer_screen.dart';
import '../features/player/presentation/mini_player.dart';
import '../features/profile/profile_screen.dart';
import '../features/vault/presentation/vault_lock_screen.dart';
import '../features/tools/whatsapp_trimmer_screen.dart';
import '../features/playlists/playlist_screen.dart';
import '../core/models/media_item.dart';
import '../app/theme/app_colors.dart';
import '../shared/widgets/ad_banner_slot.dart';
import '../shared/widgets/pro_gate.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(path: '/',        builder: (_, __) => const MySpaceScreen()),
          GoRoute(path: '/airdrop', builder: (_, __) => const AirDropScreen()),
        ],
      ),
      GoRoute(path: '/profile',       builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings',      builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/tools/folders', builder: (_, __) => const FolderBrowserScreen()),
      GoRoute(path: '/playlists',     builder: (_, __) => const PlaylistsScreen()),
      GoRoute(path: '/vault',         builder: (_, __) => const VaultLockScreen()),
      GoRoute(
        path: '/player/equalizer',
        builder: (_, __) => const ProGate(
          featureName: 'Equalizer',
          featureDescription: 'Fine-tune your audio with a 5-band equalizer.',
          child: EqualizerScreen(),
        ),
      ),
      GoRoute(
        path: '/player/video',
        builder: (_, s) => VideoPlayerScreen(mediaItem: s.extra as MediaItem),
      ),
      GoRoute(
        path: '/player/audio',
        builder: (_, s) => AudioPlayerScreen(mediaItem: s.extra as MediaItem),
      ),
      GoRoute(
        path: '/tools/whatsapp',
        builder: (_, s) => ProGate(
          featureName: 'WhatsApp Trimmer',
          featureDescription: 'Trim and compress any video to 30 seconds / 16 MB for WhatsApp.',
          child: WhatsAppTrimmerScreen(mediaItem: s.extra as MediaItem),
        ),
      ),
    ],
  );
}

// ── Main Shell ─────────────────────────────────────────────────────────────────────────────

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  // 0=AirDrop  1=MySpace(center)  2=Tools
  int _currentIndex = 1;

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    if (index == 2) { _showToolsSheet(); return; }
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    const routes = ['/airdrop', '/', ''];
    GoRouter.of(context).go(routes[index]);
  }

  void _showToolsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Tools',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 4),
            const Text('Quick utilities for your media',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            _ToolTile(
              icon: Icons.phone_android_rounded,
              label: 'WhatsApp Trimmer',
              subtitle: 'Trim & compress video to 30s / 16MB',
              color: AppColors.accent,
              isPro: true,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Open a file from My Space, then tap ⋮ → Trim for WhatsApp'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
            _ToolTile(
              icon: Icons.folder_open_rounded,
              label: 'Browse by Folder',
              subtitle: 'Navigate files by directory',
              color: AppColors.accent,
              onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/tools/folders');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          const AdBannerSlot(),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.wifi_tethering_rounded,
                      label: 'Air-Drop',
                      isActive: _currentIndex == 0,
                      onTap: () => _onTap(0),
                    ),
                    _CenterNavItem(
                      isActive: _currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.build_rounded,
                      label: 'Tools',
                      isActive: _currentIndex == 2,
                      onTap: () => _onTap(2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Center Nav Item (My Space) ─────────────────────────────────────────────────────────────────

class _CenterNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _CenterNavItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: isActive
                  ? [BoxShadow(
                      color: const Color(0xFF8A2BE2).withValues(alpha: 0.45),
                      blurRadius: 18, spreadRadius: 2)]
                  : null,
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 4),
          Text('My Space',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF8A2BE2)
                    : const Color(0xFF6B7280),
              )),
        ],
      ),
    );
  }
}

// ── Regular Nav Item ───────────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF8A2BE2).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive
                    ? const Color(0xFF8A2BE2)
                    : const Color(0xFF6B7280),
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF8A2BE2)
                      : const Color(0xFF6B7280),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Tools Sheet Tile ───────────────────────────────────────────────────────────────────────────────────

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isPro;
  final VoidCallback onTap;
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isPro = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: color,
                          )),
                      if (isPro) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.4)),
                          ),
                          child: const Text('PRO',
                              style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              )),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
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
