import 'dart:collection';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  // ── LRU caches capped at 300 entries each ─────────────────────────────────
  // LinkedHashMap with access-order tracking: oldest entry is first.
  // When the cap is reached the oldest entry is evicted (one at a time).
  static const int _kCacheMax = 300;

  static final LinkedHashMap<String, String?> _thumbCache =
      LinkedHashMap<String, String?>();
  static final LinkedHashMap<String, String?> _artCache =
      LinkedHashMap<String, String?>();

  /// Inserts [key]→[value] into [cache], evicting the oldest entry if the
  /// cache has reached [_kCacheMax] entries.
  static void _cacheInsert(
      LinkedHashMap<String, String?> cache, String key, String? value) {
    if (cache.length >= _kCacheMax) {
      cache.remove(cache.keys.first);
    }
    cache[key] = value;
  }

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

    // Fix #9: Check cache synchronously before going async — avoids an
    // unnecessary setState() call when the result is already in memory.
    final item = widget.item;
    if (item.isVideo) {
      // Cache key is filePath — item.id is Uri.encodeComponent(path) which
      // is NOT the MediaStore integer _ID that getThumbnail() needs.
      final key = item.filePath;
      if (_thumbCache.containsKey(key)) {
        _thumbPath = _thumbCache[key];
        _loaded = true;
        return; // no async needed
      }
    } else {
      final raw = item.albumArtPath;
      if (raw == null) {
        _loaded = true;
        return;
      }
      if (!raw.startsWith('albumid:')) {
        _artPath = raw;
        _loaded = true;
        return;
      }
      if (_artCache.containsKey(raw)) {
        _artPath = _artCache[raw];
        _loaded = true;
        return;
      }
    }

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
      // Use filePath as both cache key and 'id' arg. Kotlin uses 'id' only
      // as the on-disk cache filename; it uses 'path' with
      // MediaMetadataRetriever which works with any file path.
      final key = item.filePath;
      try {
        final path = await _channel.invokeMethod<String>('getVideoThumbnail', {
          'path': item.filePath,
          'id':   item.filePath,
        });
        _cacheInsert(_thumbCache, key, path);
        if (mounted) setState(() { _thumbPath = path; _loaded = true; });
      } catch (_) {
        _cacheInsert(_thumbCache, key, null);
        if (mounted) setState(() => _loaded = true);
      }
    } else {
      final raw = item.albumArtPath!; // non-albumid: paths handled in initState
      try {
        final albumId = raw.substring('albumid:'.length);
        final path = await _channel.invokeMethod<String>('getAlbumArt', {'albumId': albumId});
        _cacheInsert(_artCache, raw, path);
        if (mounted) setState(() { _artPath = path; _loaded = true; });
      } catch (_) {
        _cacheInsert(_artCache, raw, null);
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
              // Fix #18: use theme-aware surface colour
              color: AppColors.cardOf(context),
              border: Border.all(color: AppColors.borderOf(context)),
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
                        // Real thumbnail, shimmer, or modern placeholder
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

                        // Fix #15: Play button only visible while pressed
                        AnimatedBuilder(
                          animation: _press,
                          builder: (_, __) {
                            final opacity = _press.value;
                            if (opacity == 0) return const SizedBox.shrink();
                            return Center(
                              child: Opacity(
                                opacity: opacity,
                                child: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.55),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            );
                          },
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryOf(context),
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
    // Fix #2: Show shimmer while loading
    if (!_loaded) {
      return _ShimmerPlaceholder(accent: accent)
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: accent.withValues(alpha: 0.15));
    }

    final path = isVideo ? _thumbPath : _artPath;
    if (path != null) {
      // Fix #11: limit decoded image size to reduce memory pressure
      return RepaintBoundary(
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 240,
          errorBuilder: (_, __, ___) => _modernPlaceholder(isVideo, accent),
        ),
      );
    }
    return _modernPlaceholder(isVideo, accent);
  }

  // Fix #16: Modern placeholder — blurred colour field + first letter
  Widget _modernPlaceholder(bool isVideo, Color accent) {
    final letter = widget.item.title.isNotEmpty
        ? widget.item.title[0].toUpperCase()
        : (isVideo ? 'V' : 'M');
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred colour background
          Container(
            color: accent.withValues(alpha: 0.22),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(color: Colors.transparent),
          ),
          // Large first-letter centred
          Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: accent.withValues(alpha: 0.85),
                fontFamily: 'Inter',
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer base widget — a solid coloured container that flutter_animate
/// overlays with a shimmer effect.
class _ShimmerPlaceholder extends StatelessWidget {
  final Color accent;
  const _ShimmerPlaceholder({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardOf(context),
    );
  }
}
