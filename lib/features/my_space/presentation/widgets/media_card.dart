import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';

/// Reusable media card used across shelves.
class MediaCard extends StatelessWidget {
  final MediaItem item;
  final bool wide;

  const MediaCard({super.key, required this.item, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final width = wide ? 160.0 : 120.0;
    final height = wide ? 180.0 : 160.0;

    return GestureDetector(
      onTap: () {
        // Navigate to player — handled by router
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Icon(
                    item.isVideo
                        ? Icons.play_circle_outline_rounded
                        : Icons.music_note_rounded,
                    color: item.isVideo
                        ? AppColors.accent
                        : AppColors.accentViolet,
                    size: 36,
                  ),
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.formattedDuration,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
