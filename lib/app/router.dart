import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/my_space/presentation/my_space_hub_screen.dart';
import '../features/my_space/presentation/usage_stats_dashboard.dart';
import '../features/my_space/presentation/folder_browser_screen.dart' show FolderBrowserScreen, FolderDetailScreen;
import '../features/my_space/presentation/playback_history_screen.dart';
import '../features/my_space/presentation/providers/my_space_provider.dart';
import '../features/air_drop/presentation/air_drop_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/player/presentation/audio_player_screen.dart';
import '../features/player/presentation/car_mode_screen.dart';
import '../features/player/presentation/equalizer_screen.dart';
import '../features/player/presentation/mini_player.dart';
import '../features/profile/profile_screen.dart' show ProfileScreen, WhatsNewScreen;
import '../features/vault/presentation/vault_lock_screen.dart';
import '../features/tools/whatsapp_trimmer_screen.dart';
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
import '../features/auth/auth_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/verify_email_screen.dart';

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
  /// Shared navigator key — exposed so [FcmService] can obtain a [BuildContext]
  /// for showing in-app SnackBars from foreground FCM messages.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
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
          // Tab 2 — My Space hub (account + tools + quick links + settings)
          GoRoute(
            path: '/myspace',
            pageBuilder: (context, state) => _fadePage(
              context: context, state: state, child: const MySpaceHubScreen()),
          ),
        ],
      ),
      // Auth routes
      GoRoute(
        path: '/auth',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const AuthScreen()),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/auth/verify-email',
        pageBuilder: (c, s) => _fadePage(context: c, state: s, child: const VerifyEmailScreen()),
      ),
      // AirDrop remains as a push route (not a shell tab)
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
          final args = (s.extra as Map<String, dynamic>?) ?? {};
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
        path: '/stats',
        pageBuilder: (c, s) => _fadePage(
          context: c,
          state: s,
          child: Scaffold(
            backgroundColor: Theme.of(c).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(c).scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: Theme.of(c).colorScheme.onSurface, size: 20),
                onPressed: () => Navigator.of(c).pop(),
              ),
              title: Text(
                'Your Stats',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(c).colorScheme.onSurface,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            body: const SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: UsageStatsDashboard(),
            ),
          ),
        ),
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
        pageBuilder: (c, s) {
          final item = s.extra;
          if (item is! MediaItem) {
            return _fadePage(context: c, state: s, child: const SizedBox.shrink());
          }
          return _slideUpPage(context: c, state: s,
            child: VideoPlayerScreen(mediaItem: item),
          );
        },
      ),
      GoRoute(
        path: '/player/audio',
        pageBuilder: (c, s) {
          final extra = s.extra;
          if (extra is Map<String, dynamic>) {
            return _slideUpPage(
              context: c,
              state: s,
              child: AudioPlayerScreen(
                mediaItem: extra['item'] as MediaItem,
                resumeOnly: extra['resumeOnly'] as bool? ?? false,
              ),
            );
          }
          return _slideUpPage(
            context: c,
            state: s,
            child: AudioPlayerScreen(mediaItem: extra as MediaItem),
          );
        },
      ),
      GoRoute(
        path: '/player/car-mode',
        pageBuilder: (c, s) => _fadePage(
          context: c,
          state: s,
          child: const CarModeScreen(),
        ),
      ),
      GoRoute(
        path: '/music/folder',
        pageBuilder: (c, s) {
          final args = (s.extra as Map<String, dynamic>?) ?? {};
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
        path: '/music/album',
        pageBuilder: (c, s) {
          final args = (s.extra as Map<String, dynamic>?) ?? {};
          return _fadePage(
            context: c,
            state: s,
            child: MusicAlbumDetailPage(
              name: args['name'] as String,
              items: args['items'] as List<MediaItem>,
            ),
          );
        },
      ),
      GoRoute(
        path: '/music/artist',
        pageBuilder: (c, s) {
          final args = (s.extra as Map<String, dynamic>?) ?? {};
          return _fadePage(
            context: c,
            state: s,
            child: MusicArtistDetailPage(
              name: args['name'] as String,
              items: args['items'] as List<MediaItem>,
            ),
          );
        },
      ),
      GoRoute(
        path: '/tools/whatsapp',
        pageBuilder: (c, s) {
          final item = s.extra;
          if (item is! MediaItem) {
            return _fadePage(context: c, state: s, child: const SizedBox.shrink());
          }
          return _fadePage(
            context: c,
            state: s,
            child: ProGate(
              featureName: 'WhatsApp Trimmer',
              featureDescription:
                  'Trim and compress any video to 30 seconds / 16 MB for WhatsApp.',
              child: WhatsAppTrimmerScreen(mediaItem: item),
            ),
          );
        },
      ),
    ],
  );
}

// ── Global Search Delegate ────────────────────────────────────────────

/// A [SearchDelegate] that searches across both videos and music from
/// [mediaLibraryProvider] and presents results in two labelled sections.
class _GlobalSearchDelegate extends SearchDelegate<MediaItem?> {
  final List<MediaItem> _allItems;

  _GlobalSearchDelegate(this._allItems)
      : super(searchFieldLabel: 'Search videos & music…');

  // ── Helpers ──────────────────────────────────────────────────────────

  List<MediaItem> get _videos => _allItems.where((i) => i.isVideo).toList();
  List<MediaItem> get _music  => _allItems.where((i) => !i.isVideo).toList();

  List<MediaItem> _filter(List<MediaItem> items) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) {
      return i.title.toLowerCase().contains(q) ||
          i.fileName.toLowerCase().contains(q) ||
          (i.artist?.toLowerCase().contains(q) ?? false) ||
          (i.album?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── AppBar actions ───────────────────────────────────────────────────

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: () {
              query = '';
              showSuggestions(context);
            },
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () => close(context, null),
      );

  // ── Results & suggestions share the same layout ──────────────────────

  @override
  Widget buildResults(BuildContext context) => _buildResultsView(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResultsView(context);

  Widget _buildResultsView(BuildContext context) {
    final filteredVideos = _filter(_videos);
    final filteredMusic  = _filter(_music);

    if (filteredVideos.isEmpty && filteredMusic.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              query.isEmpty ? 'Start typing to search…' : 'No results for "$query"',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (filteredVideos.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.play_circle_rounded,
            label: 'Videos',
            count: filteredVideos.length,
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _MediaResultTile(
                item: filteredVideos[i],
                onTap: () {
                  close(context, filteredVideos[i]);
                  GoRouter.of(context).push('/player/video', extra: filteredVideos[i]);
                },
              ),
              childCount: filteredVideos.length,
            ),
          ),
        ],
        if (filteredMusic.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.music_note_rounded,
            label: 'Music',
            count: filteredMusic.length,
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _MediaResultTile(
                item: filteredMusic[i],
                onTap: () {
                  close(context, filteredMusic[i]);
                  GoRouter.of(context).push('/player/audio', extra: filteredMusic[i]);
                },
              ),
              childCount: filteredMusic.length,
            ),
          ),
        ],
        // Bottom padding so the last item isn't hidden behind the nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ── Section header sliver ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.2,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual result tile ────────────────────────────────────────────

class _MediaResultTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _MediaResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: item.isVideo
            ? AppColors.accent.withValues(alpha: 0.15)
            : AppColors.accentViolet.withValues(alpha: 0.15),
        child: Icon(
          item.isVideo ? Icons.play_circle_outline_rounded : Icons.music_note_rounded,
          color: item.isVideo ? AppColors.accent : AppColors.accentViolet,
          size: 20,
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (item.artist != null) item.artist!,
          item.formattedDuration,
          item.formattedSize,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontFamily: 'Inter',
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Main Shell ────────────────────────────────────────────────────────

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  static const _routes = ['/', '/music', '/myspace'];

  // TASK 1: Removed IndexedStack + _pages list.
  // Tab state is preserved by AutomaticKeepAliveClientMixin on each tab screen.
  // widget.child from ShellRoute is the single source of truth.

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    GoRouter.of(context).go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final miniItem = ref.watch(miniPlayerItemProvider);
    final hasMini  = miniItem != null;
    final allItems = ref.watch(mediaLibraryProvider).valueOrNull ?? [];

    // Derive the active tab index from the current route location so that
    // deep links and programmatic navigation keep the nav bar in sync.
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = location.startsWith('/music')
        ? 1
        : location.startsWith('/myspace')
            ? 2
            : 0;

    return Scaffold(
      appBar: AppBar(
        // Transparent / blends with the page content behind it
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Search icon only shown on Video (0) and Music (1) tabs.
        // My Space (2) has its own internal search for tools.
        actions: currentIndex == 2
            ? const []
            : [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search',
                  color: AppColors.textSecondary,
                  onPressed: () {
                    showSearch<MediaItem?>(
                      context: context,
                      delegate: _GlobalSearchDelegate(allItems),
                    );
                  },
                ),
              ],
      ),
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
                      isActive: currentIndex == 0,
                      onTap: () => _onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.music_note_rounded,
                      label: 'MUSIC',
                      isActive: currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: 'MY SPACE',
                      isActive: currentIndex == 2,
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
