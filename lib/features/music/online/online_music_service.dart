import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/environment.dart';
import '../../../core/models/media_item.dart';

class OnlineTrack {
  const OnlineTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.duration,
    required this.streamUrl,
    required this.downloadAllowed,
    required this.downloadUrl,
    required this.shareUrl,
    required this.licenseUrl,
    required this.provider,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final Duration duration;
  final String streamUrl;
  final bool downloadAllowed;
  final String downloadUrl;
  final String shareUrl;
  final String licenseUrl;
  final String provider;

  static String _text(Object? value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  factory OnlineTrack.fromJson(Map<String, dynamic> json) => OnlineTrack(
        id: _text(json['id']),
        title: _text(json['title'], 'Untitled'),
        artist: _text(json['artist'], 'Unknown artist'),
        album: _text(json['album']),
        artworkUrl: _text(json['artwork']),
        duration: Duration(
          seconds: json['durationSeconds'] is num
              ? (json['durationSeconds'] as num).round().clamp(0, 24 * 60 * 60)
              : 0,
        ),
        streamUrl: _text(json['streamUrl']),
        downloadAllowed: json['downloadAllowed'] == true,
        downloadUrl: _text(json['downloadUrl']),
        shareUrl: _text(json['shareUrl']),
        licenseUrl: _text(json['licenseUrl']),
        provider: _text(json['provider'], 'unknown'),
      );

  MediaItem toMediaItem() => MediaItem(
        id: 'online:$provider:$id',
        title: title,
        fileName: title,
        filePath: streamUrl,
        isVideo: false,
        duration: duration,
        addedAt: DateTime.now(),
        fileSizeBytes: 0,
        albumArtPath: artworkUrl.isEmpty ? null : artworkUrl,
        artist: artist,
        album: album.isEmpty ? null : album,
      );
}

class OnlineMusicException implements Exception {
  const OnlineMusicException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _CachedOnlineTracks {
  const _CachedOnlineTracks(this.createdAt, this.tracks);
  final DateTime createdAt;
  final List<OnlineTrack> tracks;
}

class OnlineMusicService {
  OnlineMusicService._();
  static final instance = OnlineMusicService._();

  static const _cacheTtl = Duration(minutes: 3);
  static const _maxCacheEntries = 32;
  final Map<String, _CachedOnlineTracks> _cache = {};

  Future<List<OnlineTrack>> discover({int limit = 24}) =>
      _load(limit: limit);

  Future<List<OnlineTrack>> search(String query, {int limit = 40}) =>
      _load(query: query.trim(), limit: limit);

  Future<List<OnlineTrack>> _load({String query = '', int limit = 24}) async {
    final safeLimit = limit.clamp(1, 50).toInt();
    final cacheKey = '${query.toLowerCase()}|$safeLimit';
    final now = DateTime.now();
    final cached = _cache[cacheKey];
    if (cached != null && now.difference(cached.createdAt) <= _cacheTtl) {
      return cached.tracks;
    }

    final uri = Uri.parse(Environment.onlineMusicUrl).replace(
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'limit': safeLimit.toString(),
      },
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const OnlineMusicException(
        'Online music is unavailable right now. Your downloaded and local music still works.',
      );
    }

    if (response.statusCode != 200) {
      throw const OnlineMusicException(
        'Online music is unavailable right now. Please try again later.',
      );
    }

    Object? body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw const OnlineMusicException(
        'Online music is unavailable right now. Your local music still works.',
      );
    }
    if (body is! Map<String, dynamic> || body['ok'] != true) {
      throw const OnlineMusicException('OTYA could not load online music.');
    }

    final raw = body['tracks'];
    if (raw is! List) return const [];
    final tracks = <OnlineTrack>[];
    for (final item in raw.whereType<Map>()) {
      try {
        final track = OnlineTrack.fromJson(Map<String, dynamic>.from(item));
        if (track.id.isNotEmpty && track.streamUrl.isNotEmpty) tracks.add(track);
      } catch (_) {
        // Ignore one malformed provider record without losing valid results.
      }
    }

    if (_cache.length >= _maxCacheEntries) {
      final oldest = _cache.entries.reduce(
        (a, b) => a.value.createdAt.isBefore(b.value.createdAt) ? a : b,
      );
      _cache.remove(oldest.key);
    }
    _cache[cacheKey] = _CachedOnlineTracks(now, List.unmodifiable(tracks));
    return _cache[cacheKey]!.tracks;
  }
}
