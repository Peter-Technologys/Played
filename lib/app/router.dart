import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme/app_colors.dart';
import '../core/models/media_item.dart';
import '../core/services/remote_control_service.dart';
import '../core/widgets/update_dialog.dart';
import '../features/ai/otya_ai_screen.dart';
import '../features/air_drop/presentation/air_drop_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/music/presentation/music_tab_screen.dart';
import '../features/my_space/presentation/folder_browser_screen.dart' show FolderBrowserScreen, FolderDetailScreen;
import '../features/my_space/presentation/my_space_hub_screen.dart';
import '../features/my_space/presentation/playback_history_screen.dart';
import '../features/my_space/presentation/usage_stats_dashboard.dart';
import '../features/player/presentation/audio_player_screen.dart';
import '../features/player/presentation/car_mode_screen.dart';
import '../features/player/presentation/equalizer_screen.dart';
import '../features/player/presentation/mini_player.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/playlists/playlist_screen.dart' show PlaylistDetailScreenById, PlaylistsScreen;
import '../features/profile/profile_screen.dart' show ProfileScreen, WhatsNewScreen;
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/privacy_policy_screen.dart';
import '../features/settings/presentation/settings_with_ai_screen.dart';
import '../features/settings/presentation/storage_analyzer_screen.dart';
import '../features/settings/presentation/theme_selection_screen.dart';
import '../features/tools/whatsapp_trimmer_screen.dart';
import '../features/vault/presentation/vault_lock_screen.dart';
import '../features/video/presentation/video_tab_screen.dart' show VideoFolderDetailPage, VideoTabScreen;
import '../features/webview/otya_webview_screen.dart';
import '../shared/widgets/pro_gate.dart';

CustomTransitionPage<void> _fadePage({required BuildContext context, required GoRouterState state, required Widget child}) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 180),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
);

CustomTransitionPage<void> _slideUpPage({required BuildContext context, required GoRouterState state, required Widget child}) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  transitionsBuilder: (_, animation, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: animation, child: child),
  ),
);

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static String? _redirect(BuildContext context, GoRouterState state) {
    final remote = RemoteControlService.instance;
    final feature = switch (state.matchedLocation) {
      '/airdrop' => 'beam',
      '/vault' => 'safe',
      '/player/equalizer' => 'equalizer',
      '/tools/whatsapp' => 'whatsappTrimmer',
      _ => null,
    };
    if (feature != null && !remote.featureEnabled(feature)) return '/myspace';
    return null;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    redirect: _redirect,
    routes: [
      ShellRoute(
        pageBuilder: (context, state, child) => _fadePage(context: context, state: state, child: _MainShell(child: child)),
        routes: [
          GoRoute(path: '/', pageBuilder: (context, state) => _fadePage(context: context, state: state, child: const VideoTabScreen())),
          GoRoute(path: '/music', pageBuilder: (context, state) => _fadePage(context: context, state: state, child: const MusicTabScreen())),
          GoRoute(path: '/myspace', pageBuilder: (context, state) => _fadePage(context: context, state: state, child: const MySpaceHubScreen())),
        ],
      ),
      GoRoute(path: '/downloads', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const DownloadsScreen())),
      GoRoute(path: '/ai', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const OtyaAiScreen())),
      GoRoute(path: '/auth', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const AuthScreen())),
      GoRoute(path: '/auth/forgot-password', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ForgotPasswordScreen())),
      GoRoute(path: '/auth/verify-email', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const VerifyEmailScreen())),
      GoRoute(path: '/airdrop', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const AirDropScreen())),
      GoRoute(path: '/profile', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ProfileScreen())),
      GoRoute(path: '/settings', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const SettingsWithAiScreen())),
      GoRoute(path: '/about', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const AboutScreen())),
      GoRoute(path: '/theme', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ThemeSelectionScreen())),
      GoRoute(path: '/tools/folders', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const FolderBrowserScreen())),
      GoRoute(
        path: '/tools/folder-detail',
        pageBuilder: (c, s) {
          final args = (s.extra as Map<String, dynamic>?) ?? {};
          return _fadePage(context: c, state: s, child: FolderDetailScreen(folderName: args['folderName'] as String, fullPath: args['fullPath'] as String, items: args['items'] as List<MediaItem>));
        },
      ),
      GoRoute(path: '/history', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const PlaybackHistoryScreen())),
      GoRoute(path: '/playlists', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const PlaylistsScreen())),
      GoRoute(path: '/playlist/:id', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: PlaylistDetailScreenById(playlistId: s.pathParameters['id']!))),
      GoRoute(path: '/vault', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const VaultLockScreen())),
      GoRoute(path: '/privacy', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const PrivacyPolicyScreen())),
      GoRoute(path: '/whats-new', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const WhatsNewScreen())),
      GoRoute(
        path: '/video/folder',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>?;
          if (args == null || args['name'] == null || args['items'] == null) return _fadePage(context: c, state: s, child: const Scaffold(body: Center(child: Text('Navigation error: missing data'))));
          return _fadePage(context: c, state: s, child: VideoFolderDetailPage(name: args['name'] as String, items: args['items'] as List<MediaItem>));
        },
      ),
      GoRoute(path: '/settings/storage', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const StorageAnalyzerScreen())),
      GoRoute(path: '/stats', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const UsageStatsDashboard())),
      GoRoute(path: '/player/equalizer', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ProGate(featureName: 'Equalizer', featureDescription: 'Fine-tune your audio with a 5-band equalizer.', child: EqualizerScreen()))),
      GoRoute(
        path: '/player/video',
        pageBuilder: (c, s) {
          final item = s.extra;
          if (item is! MediaItem) return _fadePage(context: c, state: s, child: const SizedBox.shrink());
          return _slideUpPage(context: c, state: s, child: VideoPlayerScreen(mediaItem: item));
        },
      ),
      GoRoute(
        path: '/player/audio',
        pageBuilder: (c, s) {
          final extra = s.extra;
          if (extra is Map<String, dynamic>) return _slideUpPage(context: c, state: s, child: AudioPlayerScreen(mediaItem: extra['item'] as MediaItem, resumeOnly: extra['resumeOnly'] as bool? ?? false));
          return _slideUpPage(context: c, state: s, child: AudioPlayerScreen(mediaItem: extra as MediaItem));
        },
      ),
      GoRoute(path: '/player/car-mode', pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const CarModeScreen())),
      GoRoute(
        path: '/music/folder',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>?;
          if (args == null || args['name'] == null || args['items'] == null) return _fadePage(context: c, state: s, child: const Scaffold(body: Center(child: Text('Navigation error: missing data'))));
          return _fadePage(context: c, state: s, child: MusicFolderDetailPage(name: args['name'] as String, items: args['items'] as List<MediaItem>));
        },
      ),
      GoRoute(
        path: '/music/album',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>?;
          if (args == null || args['name'] == null || args['items'] == null) return _fadePage(context: c, state: s, child: const Scaffold(body: Center(child: Text('Navigation error: missing data'))));
          return _fadePage(context: c, state: s, child: MusicAlbumDetailPage(name: args['name'] as String, items: args['items'] as List<MediaItem>));
        },
      ),
      GoRoute(
        path: '/music/artist',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>?;
          if (args == null || args['name'] == null || args['items'] == null) return _fadePage(context: c, state: s, child: const Scaffold(body: Center(child: Text('Navigation error: missing data'))));
          return _fadePage(context: c, state: s, child: MusicArtistDetailPage(name: args['name'] as String, items: args['items'] as List<MediaItem>));
        },
      ),
      GoRoute(
        path: '/webview',
        pageBuilder: (c, s) {
          final args = s.extra as Map<String, dynamic>? ?? {};
          return _fadePage(context: c, state: s, child: OtyaWebViewScreen(url: args['url'] as String? ?? 'https://petersmartlink.com/otya-player', title: args['title'] as String?));
        },
      ),
      GoRoute(
        path: '/tools/whatsapp',
        pageBuilder: (c, s) {
          final item = s.extra;
          if (item is! MediaItem) return _fadePage(context: c, state: s, child: const SizedBox.shrink());
          return _fadePage(context: c, state: s, child: ProGate(featureName: 'WhatsApp Trimmer', featureDescription: 'Trim and compress a video for sharing.', child: WhatsAppTrimmerScreen(mediaItem: item)));
        },
      ),
    ],
  );
}

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShell({required this.child});
  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  static const _routes = ['/', '/music', '/myspace'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateDialog.checkAndShow(context);
    });
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    GoRouter.of(context).go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = location.startsWith('/music') ? 1 : location.startsWith('/myspace') ? 2 : 0;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer(builder: (context, ref, _) {
            final hasMini = ref.watch(miniPlayerItemProvider) != null;
            return hasMini ? const RepaintBoundary(child: MiniPlayer()) : const SizedBox.shrink();
          }),
          Container(
            margin: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).padding.bottom + 6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111218).withValues(alpha: .98) : Colors.white.withValues(alpha: .98),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                Expanded(child: _NavItem(icon: Icons.video_library_rounded, label: 'Video', isActive: currentIndex == 0, onTap: () => _onTap(0))),
                Expanded(child: _NavItem(icon: Icons.library_music_rounded, label: 'Music', isActive: currentIndex == 1, onTap: () => _onTap(1))),
                Expanded(child: _NavItem(icon: Icons.person_rounded, label: 'Me', isActive: currentIndex == 2, onTap: () => _onTap(2))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isActive,
    label: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 30,
            decoration: BoxDecoration(color: isActive ? AppColors.accent.withValues(alpha: .14) : Colors.transparent, borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: isActive ? AppColors.accent : AppColors.textSecondary, size: 21),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? AppColors.textPrimaryOf(context) : AppColors.textSecondary)),
        ]),
      ),
    ),
  );
}
