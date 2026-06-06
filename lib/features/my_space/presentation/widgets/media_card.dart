import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
import '../providers/my_space_provider.dart';
import '../../player/presentation/queue_screen.dart';/// Modern glassmorphism media card with gradient overlay and
/// animated press feedback. Used across all shelves and the grid.
class MediaCard extends StatefulWidget {
  final MediaItem item;
  final bool wide;

  const MediaCard({super.key, required this.item, this.wide = false});

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.isVideo;
    final width  = widget.wide ? 160.0 : 120.0;
    final accent = isVideo ? AppColors.accent : AppColors.accentViolet;

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (details) {
        _press.reverse();
        // Add all items from My Space to the queue, start from this item
        final ref = ProviderScope.containerOf(context);
        final bundleAsync = ref.read(mySpaceProvider);
        bundleAsync.whenData((bundle) {
          final allItems = [
            ...bundle.recentTimeline,
            ...bundle.cinemaShelf,
            ...bundle.streetTapesShelf,
          ];
          final startIndex = allItems.indexWhere((e) => e.id == widget.item.id);
          ref.read(queueProvider.notifier).setQueue(
            allItems,
            startIndex: startIndex < 0 ? 0 : startIndex,
          );
        });
        final route = widget.item.isVideo ? '/player/video' : '/player/audio';
        context.push(route, extra: widget.item);
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: width,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // Subtle gradient card background
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1117), Color(0xFF161B27)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Thumbnail with gradient overlay ──────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(alpha: 0.15),
                                AppColors.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        // Subtle grid pattern overlay
                        Opacity(
                          opacity: 0.04,
                          child: CustomPaint(
                            painter: _GridPainter(),
                          ),
                        ),
                        // Icon centered
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.15),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.3),
                                  width: 1.5),
                            ),
                            child: Icon(
                              isVideo
                                  ? Icons.play_arrow_rounded
                                  : Icons.music_note_rounded,
                              color: accent,
                              size: 28,
                            ),
                          ),
                        ),
                        // Bottom gradient overlay for text legibility
                        const Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: SizedBox(
                            height: 40,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Color(0xCC05080F),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Type badge top-right
                        Positioned(
                          top: 8, right: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: accent.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  isVideo ? 'VIDEO' : 'AUDIO',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                    letterSpacing: 0.8,
                                    fontFamily: 'SpaceGrotesk',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Info ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'SpaceGrotesk',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 9, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            widget.item.formattedDuration,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                              fontFamily: 'SpaceGrotesk',
                            ),
                          ),
                          const Spacer(),
                          // File size dot
                          Container(
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Subtle dot-grid background painter for the card thumbnail
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    const spacing = 16.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
