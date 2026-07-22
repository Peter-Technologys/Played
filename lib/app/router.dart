import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/my_space/presentation/my_space_hub_screen.dart';
import '../features/my_space/presentation/folder_browser_screen.dart';
import '../features/my_space/presentation/playback_history_screen.dart';
import '../features/air_drop/presentation/air_drop_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/player/presentation/audio_player_screen.dart';
import '../features/player/presentation/equalizer_screen.dart';
import '../features/player/presentation/mini_player.dart';
import '../features/profile/profile_screen.dart';
import '../features/vault/presentation/vault_lock_screen.dart';
import '../features/tools/whatsapp_trimmer_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/playlists/playlist_screen.dart';
import '../features/settings/presentation/settings_detail_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/theme_selection_screen.dart';
import '../features/video/presentation/video_tab_screen.dart';
import '../features/music/presentation/music_tab_screen.dart';
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
          // Tab 0 — Video Library
          GoRoute(path: '/',        builder: (_, __) => const VideoTabScreen()),
          // Tab 1 — Music Library
          GoRoute(path: '/music',   builder: (_, __) => const MusicTabScreen()),
          // Tab 2 — My Space hub (account + quick tools + settings)
          GoRoute(path: '/myspace', builder: (_, __) => const MySpaceHubScreen()),
        ],
      ),
      // Tools & AirDrop remain as push routes (not shell tabs)
      GoRoute(path: '/tools',   builder: (_, __) => const ToolsScreen()),
      GoRoute(path: '/airdrop', builder: (_, __) => const AirDropScreen()),
      GoRoute(path: '/profile',         builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings',        builder: (_, __) => const SettingsDetailScreen()),
      GoRoute(path: '/settings-detail', builder: (_, __) => const SettingsDetailScreen()),
      GoRoute(path: '/about',           builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/theme',           builder: (_, __) => const ThemeSelectionScreen()),
      GoRoute(path: '/tools/folders',   builder: (_, __) => const FolderBrowserScreen()),
      GoRoute(path: '/history',         builder: (_, __) => const PlaybackHistoryScreen()),
      GoRoute(path: '/playlists',       builder: (_, __) => const PlaylistsScreen()),
      GoRoute(path: '/vault',           builder: (_, __) => const VaultLockScreen()),
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
          featureDescription:
              'Trim and compress any video to 30 seconds / 16 MB for WhatsApp.',
          child: WhatsAppTrimmerScreen(mediaItem: s.extra as MediaItem),
        ),
      ),
    ],
  );
}

// ── Main Shell ────────────────────────────────────────────────────────

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int _currentIndex = 0;

  static const _routes = ['/', '/music', '/myspace'];

  // IndexedStack pages — preserves tab state between switches
  final List<Widget> _pages = const [
    VideoTabScreen(),
    MusicTabScreen(),
    MySpaceHubScreen(),
  ];

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    GoRouter.of(context).go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final miniItem = ref.watch(miniPlayerItemProvider);
    final hasMini  = miniItem != null;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini-player — only rendered when a track is loaded
          if (hasMini) const RepaintBoundary(child: MiniPlayer()),
          const AdBannerSlot(),
          SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF2A2F45)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.play_circle_rounded,
                      label: 'VIDEO',
                      isActive: _currentIndex == 0,
                      onTap: () => _onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.music_note_rounded,
                      label: 'MUSIC',
                      isActive: _currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: 'MY SPACE',
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

// ── Nav Item ──────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentViolet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.30),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isActive ? Colors.black : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.black : AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
