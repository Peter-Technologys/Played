import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
// duration_formatter.dart removed — not used in this file (formatting is done inside MediaCard)
import 'media_card.dart';

/// Horizontal scrolling "Recently Played" timeline at the top of My Space.
class RecentlyPlayedTimeline extends StatelessWidget {
  final List<MediaItem> items;
  const RecentlyPlayedTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'RECENTLY PLAYED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => MediaCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}
