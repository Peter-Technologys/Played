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

  factory OnlineTrack.fromJson(Map<String, dynamic> json) => OnlineTrack(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        artist: json['artist'] as String? ?? 'Unknown artist',
        album: json['album'] as String? ?? '',
        artworkUrl: json['artwork'] as String? ?? '',
        duration: Duration(
          seconds: (json['durationSeconds'] as num?)?.round() ?? 0,
        ),
        streamUrl: json['streamUrl'] as String? ?? '',
        downloadAllowed: json['downloadAllowed'] == true,
        downloadUrl: json['downloadUrl'] as String? ?? '',
        shareUrl: json['shareUrl'] as String? ?? '',
        licenseUrl: json['licenseUrl'] as String? ?? '',
        provider: json['provider'] as String? ?? 'unknown',
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

class OnlineMusicService {
  OnlineMusicService._();
  static final instance = OnlineMusicService._();

  Future<List<OnlineTrack>> discover({int limit = 24}) =>
      _load(limit: limit);

  Future<List<OnlineTrack>> search(String query, {int limit = 40}) =>
      _load(query: query.trim(), limit: limit);

  Future<List<OnlineTrack>> _load({String query = '', int limit = 24}) async {
    final uri = Uri.parse(Environment.onlineMusicUrl).replace(
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        'limit': limit.clamp(1, 50).toString(),
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

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['ok'] != true) {
      throw const OnlineMusicException('OTYA could not load online music.');
    }

    final raw = body['tracks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => OnlineTrack.fromJson(Map<String, dynamic>.from(item)))
        .where((track) => track.id.isNotEmpty && track.streamUrl.isNotEmpty)
        .toList(growable: false);
  }
}
