import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';

/// Shared album-art thumbnail widget used across OTYA media surfaces.
///
/// Resolves `albumid:<id>` paths via the MediaStore MethodChannel and
/// displays the album art at the requested [size]. Falls back to a restrained
/// charcoal/purple placeholder when art is unavailable.
///
/// A 200-entry insertion-order cache is shared across all instances so
/// repeated lookups for the same album do not hit the platform channel again.
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
  static final LinkedHashMap<String, String?> _cache =
      LinkedHashMap<String, String?>();
  static const _maxCache = 200;

  static void _cacheSet(String key, String? value) {
    if (_cache.length >= _maxCache) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  String? _resolvedPath;
  bool _loading = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AlbumArtThumb old) {
    super.didUpdateWidget(old);
    if (old.albumArtPath != widget.albumArtPath) {
      setState(() {
        _resolvedPath = null;
        _loading = true;
      });
      _resolve();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _resolve() async {
    final raw = widget.albumArtPath;
    if (raw == null) {
      if (!_disposed && mounted) setState(() => _loading = false);
      return;
    }

    if (!raw.startsWith('albumid:')) {
      if (!_disposed && mounted) {
        setState(() {
          _resolvedPath = raw;
          _loading = false;
        });
      }
      return;
    }

    if (_cache.containsKey(raw)) {
      if (!_disposed && mounted) {
        setState(() {
          _resolvedPath = _cache[raw];
          _loading = false;
        });
      }
      return;
    }

    try {
      final albumId = raw.substring('albumid:'.length);
      final path = await _channel
          .invokeMethod<String>('getAlbumArt', {'albumId': albumId});
      _cacheSet(raw, path);
      if (!_disposed && mounted) {
        setState(() {
          _resolvedPath = path;
          _loading = false;
        });
      }
    } catch (_) {
      _cacheSet(raw, null);
      if (!_disposed && mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
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
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.16),
          ),
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
