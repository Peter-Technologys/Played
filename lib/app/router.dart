import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/my_space/presentation/my_space_hub_screen.dart';
import '../features/my_space/presentation/folder_browser_screen.dart' show FolderBrowserScreen, FolderDetailScreen;
import '../features/my_space/presentation/playback_history_screen.dart';
import '../features/air_drop/presentation/air_drop_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/player/presentation/audio_player_screen.dart';
import '../features/player/presentation/equalizer_screen.dart';
import '../features/player/presentation/mini_player.dart';
import '../features/profile/profile_screen.dart' show ProfileScreen, WhatsNewScreen;
import '../features/vault/presentation/vault_lock_screen.dart';
import '../features/tools/whatsapp_trimmer_screen.dart';
import '../features/tools/tools_screen.dart';
import '../features/playlists/playlist_screen.dart' show PlaylistsScreen, PlaylistDetailScreenById;
import '../features/settings/presentation/settings_detail_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/theme_selection_screen.dart';
import '../features/settings/presentation/privacy_policy_screen.dart';
import '../features/settings/presentation/storage_analyzer_screen.dart';
import '../features/video/presentation/video_tab_screen.dart' show VideoTabScreen, VideoFolderDetailPage;
import '../features/music/presentation/music_tab_screen.dart';
import '../core/models/media_item.dart';
import '../app/theme/app_colors.dart';
import '../shared/widgets/pro_gate.dart';

// ── Shared fade transition (200 ms) used for shell/tab routes ─────────────

CustomTransitionPage<void> _fadePage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

// ── Slide-up transition (300 ms) used for full-screen player routes ───────

CustomTransitionPage<void> _slideUpPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        pageBuilder: (context, state, child) => _fadePage(
          context: context,
          state: state,
          child: _MainShell(child: child),
        ),
        routes: [
          // Tab 0 — Video Library
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _fadePage(
              context: context, state: state, child: const VideoTabScreen()),
          ),
          // Tab 1 — Music Library
          GoRoute(
            path: '/music',
            pageBuilder: (context, state) => _fadePage(
              context: context, state: state, child: const MusicTabScreen()),
          ),
          // Tab 2 — My Space hub (account + quick tools + settings)
          GoRoute(
            path: '/myspace',
            pageBuilder: (context, state) => _fadePage(
              context: context, state: state, child: const MySpaceHubScreen()),
          ),
        ],
      ),
      // Tools & AirDrop remain as push routes (not shell tabs)
      GoRoute(
        path: '/tools',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ToolsScreen()),
      ),
      GoRoute(
        path: '/airdrop',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const AirDropScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const SettingsDetailScreen()),
      ),
      // TASK 10: /settings-detail removed — was a duplicate of /settings.
      GoRoute(
        path: '/about',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const AboutScreen()),
      ),
      GoRoute(
        path: '/theme',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ThemeSelectionScreen()),
      ),
      GoRoute(
        path: '/tools/folders',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const FolderBrowserScreen()),
      ),
      GoRoute(
        path: '/tools/folder-detail',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>;
          return _fadePage(
            context: c,
            state: s,
            child: FolderDetailScreen(
              folderName: args['folderName'] as String,
              fullPath: args['fullPath'] as String,
              items: args['items'] as List<MediaItem>,
            ),
          );
        },
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const PlaybackHistoryScreen()),
      ),
      GoRoute(
        path: '/playlists',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const PlaylistsScreen()),
      ),
      GoRoute(
        path: '/playlist/:id',
        pageBuilder: (c, s) => _fadePage(
          context: c,
          state: s,
          child: PlaylistDetailScreenById(playlistId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/vault',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const VaultLockScreen()),
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: '/whats-new',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const WhatsNewScreen()),
      ),
      GoRoute(
        path: '/video/folder',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>;
          return _fadePage(
            context: c,
            state: s,
            child: VideoFolderDetailPage(
              name: args['name'] as String,
              items: args['items'] as List<MediaItem>,
            ),
          );
        },
      ),
      GoRoute(
        path: '/settings/storage',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const StorageAnalyzerScreen()),
      ),
      GoRoute(
        path: '/player/equalizer',
        pageBuilder: (c, s) => _fadePage(
          context: c,
          state: s,
          child: const ProGate(
            featureName: 'Equalizer',
            featureDescription: 'Fine-tune your audio with a 5-band equalizer.',
            child: EqualizerScreen(),
          ),
        ),
      ),
      // TASK 4: slide-up transition for full-screen player routes
      GoRoute(
        path: '/player/video',
        pageBuilder: (c, s) => _slideUpPage(
          context: c,
          state: s,
          child: VideoPlayerScreen(mediaItem: s.extra as MediaItem),
        ),
      ),
      GoRoute(
        path: '/player/audio',
        pageBuilder: (c, s) => _slideUpPage(
          context: c,
          state: s,
          child: AudioPlayerScreen(mediaItem: s.extra as MediaItem),
        ),
      ),
      GoRoute(
        path: '/music/folder',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>;
          return _fadePage(
            context: c,
            state: s,
            child: MusicFolderDetailPage(
              name: args['name'] as String,
              items: args['items'] as List<MediaItem>,
            ),
          );
        },
      ),
      GoRoute(
        path: '/tools/whatsapp',
        pageBuilder: (c, s) => _fadePage(
          context: c,
          state: s,
          child: ProGate(
            featureName: 'WhatsApp Trimmer',
            featureDescription:
                'Trim and compress any video to 30 seconds / 16 MB for WhatsApp.',
            child: WhatsAppTrimmerScreen(mediaItem: s.extra as MediaItem),
          ),
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

  // TASK 1: Removed IndexedStack + _pages list.
  // Tab state is preserved by AutomaticKeepAliveClientMixin on each tab screen.
  // widget.child from ShellRoute is the single source of truth.

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
          // TASK 11: AdBannerSlot already returns SizedBox.shrink() when ads
          // are disabled — no visual gap. No additional guard needed.
          SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1B1E2B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2F45)
                      : const Color(0xFFE5E7EB),
                ),
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
