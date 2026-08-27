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
  static const int _kCacheMax = 300;
  static final LinkedHashMap<String, String> _thumbCache = LinkedHashMap();
  static final LinkedHashMap<String, String> _artCache = LinkedHashMap();

  static void _cacheInsert(
      LinkedHashMap<String, String> cache, String key, String? value) {
    if (value == null || value.isEmpty) return;
    if (cache.length >= _kCacheMax) cache.remove(cache.keys.first);
    cache[key] = value;
  }

  String? _thumbPath;
  String? _artPath;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));

    final item = widget.item;
    if (item.isVideo) {
      final cached = _thumbCache[item.filePath];
      if (cached != null && File(cached).existsSync()) {
        _thumbPath = cached;
        _loaded = true;
        return;
      }
    } else {
      final raw = item.albumArtPath;
      if (raw == null) {
        _loaded = true;
        return;
      }
      if (!raw.startsWith('albumid:')) {
        if (File(raw).existsSync()) _artPath = raw;
        _loaded = true;
        return;
      }
      final cached = _artCache[raw];
      if (cached != null && File(cached).existsSync()) {
        _artPath = cached;
        _loaded = true;
        return;
      }
    }
    _loadArt();
  }

  @override
  void didUpdateWidget(covariant MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.filePath != widget.item.filePath) {
      _thumbPath = null;
      _artPath = null;
      _loaded = false;
      _loadArt();
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _loadArt() async {
    final item = widget.item;
    if (item.isVideo) {
      final key = item.filePath;
      try {
        // Always ask native code for a thumbnail. Some MediaStore entries do
        // not expose an ID after moves/restores, but the native implementation
        // can still fall back to MediaMetadataRetriever using the file path.
        final path = await _channel.invokeMethod<String>('getVideoThumbnail', {
          'path': item.filePath,
          'id': item.mediaStoreId ?? '',
        });
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          _cacheInsert(_thumbCache, key, path);
        }
        if (mounted) {
          setState(() {
            _thumbPath = path;
            _loaded = true;
          });
        }
      } catch (_) {
        // Do not cache failures. A later MediaStore refresh or file move may
        // make the same thumbnail resolvable without restarting OTYA.
        if (mounted) setState(() => _loaded = true);
      }
    } else {
      final raw = item.albumArtPath;
      if (raw == null) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      if (!raw.startsWith('albumid:')) {
        if (mounted) {
          setState(() {
            _artPath = File(raw).existsSync() ? raw : null;
            _loaded = true;
          });
        }
        return;
      }
      try {
        final albumId = raw.substring('albumid:'.length);
        final path = await _channel.invokeMethod<String>(
          'getAlbumArt',
          {'albumId': albumId},
        );
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          _cacheInsert(_artCache, raw, path);
        }
        if (mounted) {
          setState(() {
            _artPath = path;
            _loaded = true;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.isVideo;
    final width = widget.wide ? 160.0 : 120.0;
    final accent = AppColors.accentViolet;

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
        context.push(isVideo ? '/player/video' : '/player/audio', extra: widget.item);
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: width,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.cardOf(context),
              border: Border.all(color: AppColors.borderOf(context)),
              boxShadow: [BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildArtwork(isVideo, accent),
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
                        Positioned(
                          bottom: 6, right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(widget.item.formattedDuration,
                              style: const TextStyle(fontSize: 9, color: Colors.white,
                                fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                          ),
                        ),
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
                                  decoration: BoxDecoration(shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.55)),
                                  child: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 24),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.title,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryOf(context), fontFamily: 'Inter'),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.schedule_rounded, size: 9, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(widget.item.formattedDuration,
                          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary,
                            fontFamily: 'Inter')),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3)),
                          child: Text(isVideo ? 'VIDEO' : 'AUDIO',
                            style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                              color: accent, letterSpacing: 0.5, fontFamily: 'Inter')),
                        ),
                      ]),
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
    if (!_loaded) {
      return _ShimmerPlaceholder(accent: accent)
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: accent.withValues(alpha: 0.15));
    }
    final path = isVideo ? _thumbPath : _artPath;
    if (path != null && File(path).existsSync()) {
      return RepaintBoundary(
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 360,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _modernPlaceholder(isVideo, accent),
        ),
      );
    }
    return _modernPlaceholder(isVideo, accent);
  }

  Widget _modernPlaceholder(bool isVideo, Color accent) {
    final letter = widget.item.title.isNotEmpty
        ? widget.item.title[0].toUpperCase()
        : (isVideo ? 'V' : 'M');
    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentBlue.withValues(alpha: .26),
                AppColors.accentViolet.withValues(alpha: .28),
                AppColors.accentPink.withValues(alpha: .22),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(color: Colors.transparent)),
        Center(child: Text(letter,
          style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.88), fontFamily: 'Inter', height: 1))),
      ]),
    );
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  final Color accent;
  const _ShimmerPlaceholder({required this.accent});

  @override
  Widget build(BuildContext context) => Container(color: AppColors.cardOf(context));
}
