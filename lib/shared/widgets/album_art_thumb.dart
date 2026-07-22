import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';

/// Shared album-art thumbnail widget used by [MusicTabScreen] song rows
/// and [MiniPlayer].
///
/// Resolves `albumid:<id>` paths via the MediaStore MethodChannel and
/// displays the album art at the requested [size]. Falls back to a
/// gradient placeholder when art is unavailable.
///
/// A 200-entry LRU cache (insertion-order eviction) is shared across all
/// instances so repeated lookups for the same album never hit the channel
/// twice.
class AlbumArtThumb extends StatefulWidget {
  /// Raw album-art path from [MediaItem.albumArtPath].
  /// May be `null`, a file path, or an `albumid:<id>` URI.
  final String? albumArtPath;

  /// Side length of the square thumbnail. Defaults to 44.
  final double size;

  /// Corner radius. Defaults to 8.
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

  // ── 200-entry LRU cache (shared across all instances) ──────────────
  static final Map<String, String?> _cache = {};
  static const _maxCache = 200;

  static void _cacheSet(String key, String? value) {
    if (_cache.length >= _maxCache) {
      // LinkedHashMap preserves insertion order — remove the oldest entry.
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
    // Plain file path — use directly.
    if (!raw.startsWith('albumid:')) {
      if (!_disposed && mounted) {
        setState(() {
          _resolvedPath = raw;
          _loading = false;
        });
      }
      return;
    }
    // Cache hit.
    if (_cache.containsKey(raw)) {
      if (!_disposed && mounted) {
        setState(() {
          _resolvedPath = _cache[raw];
          _loading = false;
        });
      }
      return;
    }
    // Resolve via MethodChannel.
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
        child: _loading
            ? Container(color: AppColors.border)
            : _resolvedPath != null
                ? Image.file(
                    File(_resolvedPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accentViolet, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white,
          size: widget.size * 0.45,
        ),
      );
}
