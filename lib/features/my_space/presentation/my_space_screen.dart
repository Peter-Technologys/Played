import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/shelf_sorter.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'providers/my_space_provider.dart';
import 'widgets/media_card.dart';
import 'widgets/cinema_shelf.dart';
import 'widgets/street_tapes_shelf.dart';
import 'widgets/recently_played_timeline.dart';
import 'widgets/search_bar_widget.dart';

class MySpaceScreen extends ConsumerWidget {
  const MySpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(mySpaceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: bundleAsync.when(
          loading: () => const _ScanningLoader(),
          error: (e, st) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(mySpaceProvider)),
          data: (bundle) => _SpaceContent(bundle: bundle),
        ),
      ),
    );
  }
}

// ── Content ──────────────────────────────────────────────────

class _SpaceContent extends ConsumerWidget {
  final ShelfBundle bundle;
  const _SpaceContent({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalFiles = bundle.recentTimeline.length +
        bundle.cinemaShelf.length +
        bundle.streetTapesShelf.length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [

        // ── Header ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Space',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk',
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '$totalFiles files on device',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                // Refresh button
                _IconBtn(
                  icon: Icons.refresh_rounded,
                  onTap: () => ref.invalidate(mySpaceProvider),
                ),
                const SizedBox(width: 8),
                // Search button
                _IconBtn(
                  icon: Icons.search_rounded,
                  onTap: () => showSearch(
                    context: context,
                    delegate: MediaSearchDelegate(
                      allItems: [
                        ...bundle.recentTimeline,
                        ...bundle.cinemaShelf,
                        ...bundle.streetTapesShelf,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── Empty state ──────────────────────────────────────
        if (totalFiles == 0)
          const SliverFillRemaining(
            child: _EmptyState(),
          ),

        // ── Recently Played Timeline ────────────────────────
        if (bundle.recentTimeline.isNotEmpty) ...
          [
            SliverToBoxAdapter(
              child: RecentlyPlayedTimeline(items: bundle.recentTimeline)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],

        // ── Cinema Shelf ───────────────────────────────────
        if (bundle.hasCinema) ...
          [
            SliverToBoxAdapter(
              child: CinemaShelf(items: bundle.cinemaShelf)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],

        // ── Street Tapes Shelf ────────────────────────────
        if (bundle.hasStreetTapes) ...
          [
            SliverToBoxAdapter(
              child: StreetTapesShelf(items: bundle.streetTapesShelf)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],

        // ── All Files Grid ──────────────────────────────────
        if (totalFiles > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('ALL FILES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                        fontFamily: 'SpaceGrotesk',
                      )),
                  const Spacer(),
                  Text('$totalFiles total',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),

        if (totalFiles > 0)
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

        if (totalFiles > 0)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final all = [
                    ...bundle.recentTimeline,
                    ...bundle.cinemaShelf,
                    ...bundle.streetTapesShelf,
                  ];
                  return MediaCard(item: all[i])
                      .animate()
                      .fadeIn(
                        duration: 300.ms,
                        delay: Duration(milliseconds: i * 40),
                      )
                      .slideY(begin: 0.05);
                },
                childCount: [
                  ...bundle.recentTimeline,
                  ...bundle.cinemaShelf,
                  ...bundle.streetTapesShelf,
                ].length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Icon Button ─────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: AppColors.textSecondary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('No media found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'SpaceGrotesk',
              )),
          const SizedBox(height: 8),
          const Text(
            'Add audio or video files to your device\nand tap refresh to scan.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Scanning Loader ─────────────────────────────────────────

class _ScanningLoader extends StatelessWidget {
  const _ScanningLoader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Header shimmer
          const LoadingShimmer(height: 32, width: 160),
          const SizedBox(height: 8),
          const LoadingShimmer(height: 14, width: 100),
          const SizedBox(height: 28),
          const MediaGridShimmer(count: 4),
          const SizedBox(height: 28),
          const MediaGridShimmer(count: 4),
        ],
      ),
    );
  }
}

// ── Error View ─────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text('Could not scan media',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SpaceGrotesk',
                )),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Try Again',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'SpaceGrotesk',
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
