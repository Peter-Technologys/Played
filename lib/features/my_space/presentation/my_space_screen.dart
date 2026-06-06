import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/shelf_sorter.dart';
import 'providers/my_space_provider.dart';
import 'widgets/media_card.dart';
import 'widgets/cinema_shelf.dart';
import 'widgets/street_tapes_shelf.dart';
import 'widgets/recently_played_timeline.dart';

// ── Screen ────────────────────────────────────────────────────

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
          error: (e, st) => _ErrorView(message: e.toString()),
          data: (bundle) => _SpaceContent(bundle: bundle),
        ),
      ),
    );
  }
}

// ── Content ─────────────────────────────────────────────────

class _SpaceContent extends StatelessWidget {
  final ShelfBundle bundle;
  const _SpaceContent({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Header ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Space',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                    Text(
                      '${bundle.recentTimeline.length + bundle.cinemaShelf.length + bundle.streetTapesShelf.length} files',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Search icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // ── Recently Played Timeline ────────────────────────
        if (bundle.recentTimeline.isNotEmpty)
          SliverToBoxAdapter(
            child: RecentlyPlayedTimeline(
              items: bundle.recentTimeline,
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // ── Cinema Shelf ───────────────────────────────────
        if (bundle.hasCinema)
          SliverToBoxAdapter(
            child: CinemaShelf(
              items: bundle.cinemaShelf,
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          ),

        if (bundle.hasCinema)
          const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // ── Street Tapes Shelf ────────────────────────────
        if (bundle.hasStreetTapes)
          SliverToBoxAdapter(
            child: StreetTapesShelf(
              items: bundle.streetTapesShelf,
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ── Loading State ───────────────────────────────────────────

class _ScanningLoader extends StatelessWidget {
  const _ScanningLoader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Scanning your media...',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_rounded,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not scan media',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
