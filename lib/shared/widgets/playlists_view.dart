import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../features/playlists/playlist_screen.dart' show playlistsProvider;

/// Shared playlists list widget used by both [VideoTabScreen] and
/// [MusicTabScreen].
///
/// Shows a list of playlists from [playlistsProvider]. When empty, displays
/// an empty-state icon and — if [showCreateButton] is true — a "Create
/// Playlist" button that navigates to `/playlists`.
class PlaylistsView extends ConsumerWidget {
  /// Whether to show a "Create Playlist" button in the empty state.
  /// Defaults to true (matches the video tab behaviour).
  final bool showCreateButton;

  const PlaylistsView({super.key, this.showCreateButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    if (playlists.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _EmptyState(
            icon: Icons.queue_music_rounded,
            label: 'No playlists yet',
          ),
          if (showCreateButton) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/playlists');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentViolet],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Create Playlist',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: playlists.length,
      itemBuilder: (context, i) {
        final pl = playlists[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.queue_music_rounded,
                  color: AppColors.accentViolet, size: 22),
            ),
            title: Text(
              pl.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            subtitle: Text(
              '${pl.mediaIds.length} track${pl.mediaIds.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/playlists');
            },
          ),
        );
      },
    );
  }
}

// ── Private empty-state helper ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentViolet.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accentViolet, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
