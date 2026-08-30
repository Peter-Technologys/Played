import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../shared/widgets/otya_logo.dart';
import 'online_music_service.dart';
import 'spotify_service.dart';

class OnlineMusicScreen extends StatefulWidget {
  const OnlineMusicScreen({super.key});

  @override
  State<OnlineMusicScreen> createState() => _OnlineMusicScreenState();
}

class _OnlineMusicScreenState extends State<OnlineMusicScreen> {
  final _searchController = TextEditingController();
  Future<List<OnlineTrack>>? _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = OnlineMusicService.instance.discover();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    HapticFeedback.selectionClick();
    setState(() {
      _tracks = query.isEmpty
          ? OnlineMusicService.instance.discover()
          : OnlineMusicService.instance.search(query);
    });
  }

  Future<void> _searchSpotify() async {
    HapticFeedback.selectionClick();
    final opened = await SpotifyService.instance.openSearch(
      _searchController.text.trim(),
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Spotify right now.')),
      );
    }
  }

  void _play(OnlineTrack track) {
    HapticFeedback.lightImpact();
    final item = MediaItem(
      id: 'online:${track.provider}:${track.id}',
      title: track.title,
      fileName: track.title,
      filePath: track.streamUrl,
      isVideo: false,
      duration: track.duration,
      addedAt: DateTime.now(),
      fileSizeBytes: 0,
      albumArtPath: track.artworkUrl.isEmpty ? null : track.artworkUrl,
      artist: track.artist,
      album: track.album.isEmpty ? null : track.album,
    );
    context.push('/player/audio', extra: item);
  }

  Future<void> _download(OnlineTrack track) async {
    if (!track.downloadAllowed || track.downloadUrl.isEmpty) return;
    HapticFeedback.selectionClick();
    final uri = Uri.tryParse(track.downloadUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start this download.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Android is downloading this track to your phone.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: const Row(
          children: [
            OtyaMark(size: 30),
            SizedBox(width: 10),
            Text('Online Music'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search songs or artists',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search OTYA online music',
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _SourceCard(
                    icon: Icons.public_rounded,
                    title: 'Independent',
                    subtitle: 'Jamendo · play here',
                    onTap: _search,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SourceCard(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Spotify',
                    subtitle: 'Search & listen online',
                    onTap: _searchSpotify,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Jamendo tracks play in OTYA and can show downloads when the artist permits them. Spotify stays a separate connected source and does not expose Spotify songs as downloadable files.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<OnlineTrack>>(
              future: _tracks,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _OnlineMusicError(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(
                      () => _tracks = OnlineMusicService.instance.discover(),
                    ),
                  );
                }
                final tracks = snapshot.data ?? const <OnlineTrack>[];
                if (tracks.isEmpty) {
                  return const Center(
                    child: Text('No tracks found. Try another search.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return _OnlineTrackTile(
                      track: track,
                      onPlay: () => _play(track),
                      onDownload:
                          track.downloadAllowed ? () => _download(track) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _OnlineTrackTile extends StatelessWidget {
  const _OnlineTrackTile({
    required this.track,
    required this.onPlay,
    required this.onDownload,
  });

  final OnlineTrack track;
  final VoidCallback onPlay;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final minutes = track.duration.inMinutes;
    final seconds =
        track.duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return ListTile(
      minTileHeight: 68,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: 52,
          child: track.artworkUrl.isEmpty
              ? const ColoredBox(
                  color: AppColors.surfaceElevated,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppColors.accent,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: track.artworkUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: AppColors.surfaceElevated,
                    child: Icon(
                      Icons.music_note_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                ),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${track.artist}${minutes > 0 ? ' · $minutes:$seconds' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onPlay,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDownload != null)
            IconButton(
              tooltip: 'Download to phone',
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded),
            ),
          IconButton(
            tooltip: 'Play',
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

class _OnlineMusicError extends StatelessWidget {
  const _OnlineMusicError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OtyaMark(size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your local and downloaded music still works offline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}
