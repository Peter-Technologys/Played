import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/environment.dart';

/// Spotify integration boundary for OTYA.
///
/// Spotify is intentionally kept separate from OTYA's local/Jamendo playback
/// pipeline. Spotify content is never exposed as a raw downloadable media URL.
class SpotifyService {
  SpotifyService._();
  static final instance = SpotifyService._();

  bool get configured => Environment.spotifyClientId.trim().isNotEmpty;

  Uri searchUri(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return Uri.parse('https://open.spotify.com/');
    return Uri.parse(
      'https://open.spotify.com/search/${Uri.encodeComponent(cleaned)}',
    );
  }

  Future<bool> openSearch(String query) => _open(searchUri(query));

  Future<bool> openSpotify() => _open(Uri.parse('https://open.spotify.com/'));

  Future<bool> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
