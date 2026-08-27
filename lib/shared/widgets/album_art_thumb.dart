import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';

/// Shared album-art thumbnail widget used across OTYA media surfaces.
class AlbumArtThumb extends StatefulWidget {
  final String? albumArtPath;
  final double size;
  final double borderRadius;

  const AlbumArtThumb({
    super.key,
    this.albumArtPath,
    this.size = 44,
    this.borderRadius = 8,
  });

  @override
  State<AlbumArtThumb> createState() => _AlbumArtThumbState();
}

class _AlbumArtThumbState extends State<AlbumArtThumb> {
  static const _channel = MethodChannel('com.otyaplayer.app/media_store');
  static final LinkedHashMap<String, String?> _cache = LinkedHashMap();
  static final Map<String, Future<String?>> _inFlight = {};
  static const _maxCache = 200;

  static void _cacheSet(String key, String? value) {
    // Refresh recency when an existing entry is resolved again.
    _cache.remove(key);
    while (_cache.length >= _maxCache && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  static Future<String?> _lookupAlbumArt(String raw) {
    final cached = _cache[raw];
    if (_cache.containsKey(raw)) {
      // Touch the entry so frequently used art is less likely to be evicted.
      _cache.remove(raw);
      _cache[raw] = cached;
      return Future.value(cached);
    }

    return _inFlight.putIfAbsent(raw, () async {
      try {
        final albumId = raw.substring('albumid:'.length);
        final path = await _channel
            .invokeMethod<String>('getAlbumArt', {'albumId': albumId})
            .timeout(const Duration(seconds: 5));
        _cacheSet(raw, path);
        return path;
      } catch (_) {
        _cacheSet(raw, null);
        return null;
      } finally {
        _inFlight.remove(raw);
      }
    });
  }

  String? _resolvedPath;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AlbumArtThumb old) {
    super.didUpdateWidget(old);
    if (old.albumArtPath != widget.albumArtPath) {
      _generation++;
      setState(() {
        _resolvedPath = null;
        _loading = true;
      });
      _resolve();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    final raw = widget.albumArtPath;

    String? resolved;
    if (raw == null || raw.isEmpty) {
      resolved = null;
    } else if (!raw.startsWith('albumid:')) {
      resolved = raw;
    } else {
      resolved = await _lookupAlbumArt(raw);
    }

    if (!mounted || generation != _generation || raw != widget.albumArtPath) {
      return;
    }
    setState(() {
      _resolvedPath = resolved;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodeSize = (widget.size * pixelRatio).round().clamp(1, 2048);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _loading
              ? _loadingSurface(context)
              : _resolvedPath != null
                  ? Image.file(
                      File(_resolvedPath!),
                      key: ValueKey(_resolvedPath),
                      fit: BoxFit.cover,
                      cacheWidth: decodeSize,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
        ),
      ),
    );
  }

  Widget _loadingSurface(BuildContext context) => Container(
        key: const ValueKey('loading-art'),
        color: AppColors.cardOf(context),
        alignment: Alignment.center,
        child: SizedBox(
          width: widget.size * 0.22,
          height: widget.size * 0.22,
          child: const CircularProgressIndicator(
            strokeWidth: 1.8,
            color: AppColors.accent,
          ),
        ),
      );

  Widget _placeholder(BuildContext context) => Container(
        key: const ValueKey('placeholder-art'),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: widget.size * 0.65,
                height: widget.size * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ),
            Center(
              child: Container(
                width: widget.size * 0.52,
                height: widget.size * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: AppColors.accent,
                  size: widget.size * 0.28,
                ),
              ),
            ),
          ],
        ),
      );
}
