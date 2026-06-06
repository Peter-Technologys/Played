import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/shelf_sorter.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'providers/my_space_provider.dart';
import 'widgets/media_card.dart';
import 'widgets/cinema_shelf.dart';
import 'widgets/street_tapes_shelf.dart';
import 'widgets/recently_played_timeline.dart';
import 'widgets/search_bar_widget.dart';

// ── Sort options ─────────────────────────────────────────────
enum MediaSort { dateAdded, name, size, duration }

final mediaSortProvider = StateProvider<MediaSort>((_) => MediaSort.dateAdded);

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
          error: (e, st) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(mySpaceProvider)),
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
    final sort = ref.watch(mediaSortProvider);

    final allItems = [
      ...bundle.recentTimeline,
      ...bundle.cinemaShelf,
      ...bundle.streetTapesShelf,
    ];

    final sorted = List.of(allItems)
      ..sort((a, b) {
        switch (sort) {
          case MediaSort.name:
            return a.title.compareTo(b.title);
          case MediaSort.size:
            return b.fileSizeBytes.compareTo(a.fileSizeBytes);
          case MediaSort.duration:
            return (b.duration ?? Duration.zero)
                .compareTo(a.duration ?? Duration.zero);
          case MediaSort.dateAdded:
            return b.addedAt.compareTo(a.addedAt);
        }
      });

    final totalFiles = allItems.length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [

        // ── Header ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title block
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Space',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalFiles files on device',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),

                // Search
                _IconBtn(
                  icon: Icons.search_rounded,
                  onTap: () => showSearch(
                    context: context,
                    delegate: MediaSearchDelegate(allItems: allItems),
                  ),
                ),
                const SizedBox(width: 8),

                // Sort / Filter
                _SortButton(current: sort),
                const SizedBox(width: 8),

                // Refresh
                _IconBtn(
                  icon: Icons.refresh_rounded,
                  onTap: () => ref.invalidate(mySpaceProvider),
                ),
                const SizedBox(width: 8),

                // Settings — core action for the whole app
                _IconBtn(
                  icon: Icons.settings_rounded,
                  onTap: () => context.push('/settings'),
                  accent: true,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── Empty state ──────────────────────────────────────
        if (totalFiles == 0)
          const SliverFillRemaining(child: _EmptyState()),

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

        // ── All Files header ────────────────────────────────
        if (totalFiles > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'ALL FILES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalFiles total',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

        if (totalFiles > 0)
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── All Files Grid ──────────────────────────────────
        if (totalFiles > 0)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) => MediaCard(item: sorted[i])
                    .animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: i * 40),
                    )
                    .slideY(begin: 0.05),
                childCount: sorted.length,
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

// ── Sort Button ─────────────────────────────────────────────

class _SortButton extends ConsumerWidget {
  final MediaSort current;
  const _SortButton({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showSortSheet(context, ref),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: current != MediaSort.dateAdded
                ? AppColors.accent
                : AppColors.border,
          ),
        ),
        child: Icon(
          Icons.sort_rounded,
          color: current != MediaSort.dateAdded
              ? AppColors.accent
              : AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sort Files',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
            const SizedBox(height: 16),
            ...MediaSort.values.map((s) {
              final label = switch (s) {
                MediaSort.dateAdded => 'Date Added (newest first)',
                MediaSort.name => 'Name (A → Z)',
                MediaSort.size => 'File Size (largest first)',
                MediaSort.duration => 'Duration (longest first)',
              };
              final icon = switch (s) {
                MediaSort.dateAdded => Icons.calendar_today_rounded,
                MediaSort.name => Icons.sort_by_alpha_rounded,
                MediaSort.size => Icons.data_usage_rounded,
                MediaSort.duration => Icons.timer_rounded,
              };
              final isActive = current == s;
              return ListTile(
                leading: Icon(icon,
                    color: isActive
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    size: 20),
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontWeight: isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
                trailing: isActive
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.accent, size: 18)
                    : null,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  ref.read(mediaSortProvider.notifier).state = s;
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Icon Button ─────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  const _IconBtn(
      {required this.icon, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: accent ? AppColors.accent : AppColors.border),
        ),
        child: Icon(
          icon,
          color: accent ? AppColors.accent : AppColors.textSecondary,
          size: 20,
        ),
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
          const Text(
            'No media found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
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
        children: const [
          SizedBox(height: 24),
          LoadingShimmer(height: 32, width: 160),
          SizedBox(height: 8),
          LoadingShimmer(height: 14, width: 100),
          SizedBox(height: 28),
          MediaGridShimmer(count: 4),
          SizedBox(height: 28),
          MediaGridShimmer(count: 4),
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
            const Text(
              'Could not scan media',
              style: TextStyle(
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
                  color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
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
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
