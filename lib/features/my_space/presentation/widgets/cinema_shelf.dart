import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
import 'media_card.dart';

/// Dynamic “Cinema” shelf — videos longer than 45 minutes.
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentViolet],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\uD83C\uDFAC',
                        style: TextStyle(fontSize: 12)),
                    SizedBox(width: 5),
                    Text(
                      'CINEMA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 1.2,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} films',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
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
