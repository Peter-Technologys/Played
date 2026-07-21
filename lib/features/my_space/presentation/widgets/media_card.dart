import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';
import '../providers/my_space_provider.dart';
import '../../../player/presentation/queue_screen.dart';

/// Modern media card with real thumbnails/album art.
/// Used across all shelves and the grid.
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

  static const _channel = MethodChannel('com.otyaplayer.app/media_store');

  // Thumbnail / album art cache (session-level, shared across all cards)
  static final Map<String, String?> _thumbCache = {};
  static final Map<String, String?> _artCache   = {};

  String? _thumbPath;
  String? _artPath;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _press, curve: Curves.easeOut));
    _loadArt();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _loadArt() async {
    final item = widget.item;
    if (item.isVideo) {
      final key = item.id;
      if (_thumbCache.containsKey(key)) {
        if (mounted) setState(() { _thumbPath = _thumbCache[key]; _loaded = true; });
        return;
      }
      try {
        final path = await _channel.invokeMethod<String>('getVideoThumbnail', {
          'path': item.filePath,
          'id':   item.id,
        });
        _thumbCache[key] = path;
        if (mounted) setState(() { _thumbPath = path; _loaded = true; });
      } catch (_) {
        _thumbCache[key] = null;
        if (mounted) setState(() => _loaded = true);
      }
    } else {
      final raw = item.albumArtPath;
      if (raw == null) { if (mounted) setState(() => _loaded = true); return; }
      if (!raw.startsWith('albumid:')) {
        if (mounted) setState(() { _artPath = raw; _loaded = true; });
        return;
      }
      if (_artCache.containsKey(raw)) {
        if (mounted) setState(() { _artPath = _artCache[raw]; _loaded = true; });
        return;
      }
      try {
        final albumId = raw.substring('albumid:'.length);
        final path = await _channel.invokeMethod<String>('getAlbumArt', {'albumId': albumId});
        _artCache[raw] = path;
        if (mounted) setState(() { _artPath = path; _loaded = true; });
      } catch (_) {
        _artCache[raw] = null;
        if (mounted) setState(() => _loaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.isVideo;
    final width   = widget.wide ? 160.0 : 120.0;
    final accent  = isVideo ? AppColors.accent : AppColors.accentViolet;

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        final ref = ProviderScope.containerOf(context);
        final allItems = ref.read(mySpaceProvider).valueOrNull ?? [];
        final startIndex = allItems.indexWhere((e) => e.id == widget.item.id);
        ref.read(queueProvider.notifier).setQueue(
          allItems,
          startIndex: startIndex < 0 ? 0 : startIndex,
        );
        context.push(
          isVideo ? '/player/video' : '/player/audio',
          extra: widget.item,
        );
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: width,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Thumbnail / art area ──────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Real thumbnail or gradient placeholder
                        _buildArtwork(isVideo, accent),

                        // Bottom gradient scrim
                        const Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: SizedBox(
                            height: 36,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Color(0xCC0F1117)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Duration badge (bottom-right)
                        Positioned(
                          bottom: 6, right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.item.formattedDuration,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),

                        // Play button overlay (center)
                        Center(
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Title + type badge ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
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
                              fontFamily: 'Inter',
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              isVideo ? 'VIDEO' : 'AUDIO',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 0.5,
                                fontFamily: 'Inter',
                              ),
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

  Widget _buildArtwork(bool isVideo, Color accent) {
    if (isVideo) {
      if (_thumbPath != null) {
        return Image.file(
          File(_thumbPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientPlaceholder(isVideo, accent),
        );
      }
      return _gradientPlaceholder(isVideo, accent);
    } else {
      if (_artPath != null) {
        return Image.file(
          File(_artPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientPlaceholder(isVideo, accent),
        );
      }
      return _gradientPlaceholder(isVideo, accent);
    }
  }

  Widget _gradientPlaceholder(bool isVideo, Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
          color: accent.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }
}
