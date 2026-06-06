import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/my_space/presentation/my_space_screen.dart';
import '../features/air_drop/presentation/air_drop_screen.dart';
import '../features/studio/presentation/studio_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/player/presentation/audio_player_screen.dart';
import '../features/player/presentation/equalizer_screen.dart';
import '../features/player/presentation/lyrics_screen.dart';
import '../features/player/presentation/queue_screen.dart';
import '../features/player/presentation/mini_player.dart';
import '../features/settings/settings_screen.dart';
import '../features/vault/presentation/vault_lock_screen.dart';
import '../features/tools/whatsapp_trimmer_screen.dart';
import '../core/models/media_item.dart';
import '../app/theme/app_colors.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // ── Main Shell (3-tab layout) ──────────────────────────────
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const MySpaceScreen(),
          ),
          GoRoute(
            path: '/airdrop',
            builder: (_, __) => const AirDropScreen(),
          ),
          GoRoute(
            path: '/studio',
            builder: (_, __) => const StudioScreen(),
          ),
        ],
      ),

      // ── Settings (full-screen) ────────────────────────────────
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),

      // ── Vault (accessed from Settings) ────────────────────────
      GoRoute(
        path: '/vault',
        builder: (_, __) => const VaultLockScreen(),
      ),

      // ── Player screens ────────────────────────────────────────
      GoRoute(
        path: '/player/video',
        builder: (context, state) {
          final item = state.extra as MediaItem;
          return VideoPlayerScreen(mediaItem: item);
        },
      ),
      GoRoute(
        path: '/player/audio',
        builder: (context, state) {
          final item = state.extra as MediaItem;
          return AudioPlayerScreen(mediaItem: item);
        },
      ),
      GoRoute(
        path: '/player/equalizer',
        builder: (_, __) => const EqualizerScreen(),
      ),

      // ── Tools ─────────────────────────────────────────────────
      GoRoute(
        path: '/tools/whatsapp',
        builder: (context, state) {
          final item = state.extra as MediaItem;
          return WhatsAppTrimmerScreen(mediaItem: item);
        },
      ),
    ],
  );
}

// ── Main Shell with Bottom Nav + MiniPlayer ────────────────────

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int _currentIndex = 0;

  static const List<String> _routes = ['/', '/airdrop', '/studio'];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    GoRouter.of(context).go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Persistent Mini Player ───────────────────────────
          const MiniPlayer(),

          // ── Bottom Nav ───────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              border: Border(
                top: BorderSide(color: Color(0xFF1F2937), width: 1),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: 'My Space',
                      isActive: _currentIndex == 0,
                      onTap: () => _onTabTap(0),
                    ),
                    _NavItem(
                      icon: Icons.wifi_tethering_rounded,
                      label: 'Air-Drop',
                      isActive: _currentIndex == 1,
                      onTap: () => _onTabTap(1),
                    ),
                    _NavItem(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Studio',
                      isActive: _currentIndex == 2,
                      onTap: () => _onTabTap(2),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00D4FF).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? const Color(0xFF00D4FF)
                  : const Color(0xFF6B7280),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? const Color(0xFF00D4FF)
                    : const Color(0xFF6B7280),
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
