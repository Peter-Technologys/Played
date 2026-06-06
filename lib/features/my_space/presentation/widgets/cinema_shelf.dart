import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
import 'media_card.dart';

/// Dynamic "Cinema" shelf — videos longer than 45 minutes.
class CinemaShelf extends StatelessWidget {
  final List<MediaItem> items;
  const CinemaShelf({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('\uD83C\uDFAC', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'CINEMA',
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
                '${items.length} films',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                MediaCard(item: items[i], wide: true),
          ),
        ),
      ],
    );
  }
}
