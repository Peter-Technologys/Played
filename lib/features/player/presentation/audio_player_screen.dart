import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/database/played_database.dart';
import '../../../core/utils/duration_formatter.dart';

// ── Providers ────────────────────────────────────────────────

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) => AudioPlayerNotifier(),
);

class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool isLoading;

  const AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.isLoading = true,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? isLoading,
  }) =>
      AudioPlayerState(
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final AudioPlayer _player = AudioPlayer();
  AudioPlayerNotifier() : super(const AudioPlayerState()) {
    _player.playerStateStream.listen((s) {
      state = state.copyWith(
        isPlaying: s.playing,
        isLoading: s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      );
    });
    _player.positionStream.listen((p) {
      state = state.copyWith(position: p);
    });
    _player.durationStream.listen((d) {
      if (d != null) state = state.copyWith(duration: d);
    });
  }

  Future<void> load(MediaItem item) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final saved = PlayedDatabase.instance.getSeekPosition(item.id);
    await _player.setFilePath(item.filePath);
    if (saved != null) await _player.seek(saved);
    await _player.play();
  }

  void togglePlay() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> skipForward() =>
      _player.seek(state.position + const Duration(seconds: 10));

  Future<void> skipBack() =>
      _player.seek(state.position - const Duration(seconds: 10));

  void setSpeed(double speed) {
    _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  void savePosition(String mediaId) {
    PlayedDatabase.instance.saveSeekPosition(mediaId, state.position);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

// ── Screen ───────────────────────────────────────────────────

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  const AudioPlayerScreen({super.key, required this.mediaItem});

  @override
  ConsumerState<AudioPlayerScreen> createState() =>
      _AudioPlayerScreenState();
}

class _AudioPlayerScreenState
    extends ConsumerState<AudioPlayerScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioPlayerProvider.notifier).load(widget.mediaItem);
      PlayedDatabase.instance.recordPlay(widget.mediaItem);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref
          .read(audioPlayerProvider.notifier)
          .savePosition(widget.mediaItem.id);
    }
  }

  @override
  void dispose() {
    ref
        .read(audioPlayerProvider.notifier)
        .savePosition(widget.mediaItem.id);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary,
                        size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'NOW PLAYING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.textSecondary, size: 22),
                    onPressed: () => _showOptionsSheet(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Album Art ──────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _AlbumArt(
                  albumArtPath: widget.mediaItem.albumArtPath,
                  isPlaying: playerState.isPlaying,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Track Info ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    widget.mediaItem.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.mediaItem.artist ?? 'Unknown Artist',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Seek Bar ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SeekBar(
                position: playerState.position,
                duration: playerState.duration,
                onSeek: (d) =>
                    ref.read(audioPlayerProvider.notifier).seek(d),
              ),
            ),

            const SizedBox(height: 24),

            // ── Controls ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _Controls(
                isPlaying: playerState.isPlaying,
                isLoading: playerState.isLoading,
                speed: playerState.speed,
                onTogglePlay: () =>
                    ref.read(audioPlayerProvider.notifier).togglePlay(),
                onSkipBack: () =>
                    ref.read(audioPlayerProvider.notifier).skipBack(),
                onSkipForward: () =>
                    ref.read(audioPlayerProvider.notifier).skipForward(),
                onSpeedChange: (s) =>
                    ref.read(audioPlayerProvider.notifier).setSpeed(s),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OptionsSheet(mediaItem: widget.mediaItem),
    );
  }
}

// ── Album Art Widget ─────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final String? albumArtPath;
  final bool isPlaying;

  const _AlbumArt({this.albumArtPath, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      transform: Matrix4.identity()
        ..scale(isPlaying ? 1.0 : 0.88),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(isPlaying ? 0.3 : 0.1),
            blurRadius: isPlaying ? 40 : 16,
            spreadRadius: isPlaying ? 4 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: albumArtPath != null
            ? Image.file(
                File(albumArtPath!),
                fit: BoxFit.cover,
                width: double.infinity,
              )
            : Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppColors.accent,
                    size: 80,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Seek Bar ─────────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withOpacity(0.2),
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: progress,
            onChanged: (v) {
              final target = Duration(
                milliseconds: (v * duration.inMilliseconds).toInt(),
              );
              onSeek(target);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.format(position),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                DurationFormatter.format(duration),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Controls ─────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final double speed;
  final VoidCallback onTogglePlay;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final ValueChanged<double> onSpeedChange;

  const _Controls({
    required this.isPlaying,
    required this.isLoading,
    required this.speed,
    required this.onTogglePlay,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Speed toggle
        GestureDetector(
          onTap: () {
            final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
            final idx = speeds.indexOf(speed);
            onSpeedChange(speeds[(idx + 1) % speeds.length]);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '${speed}x',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ),
        ),

        // Skip back
        IconButton(
          icon: const Icon(Icons.replay_10_rounded,
              color: AppColors.textPrimary, size: 32),
          onPressed: onSkipBack,
        ),

        // Play / Pause
        GestureDetector(
          onTap: onTogglePlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 36,
                  ),
          ),
        ),

        // Skip forward
        IconButton(
          icon: const Icon(Icons.forward_10_rounded,
              color: AppColors.textPrimary, size: 32),
          onPressed: onSkipForward,
        ),

        // Placeholder for future queue button
        IconButton(
          icon: const Icon(Icons.queue_music_rounded,
              color: AppColors.textSecondary, size: 26),
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── Options Bottom Sheet ─────────────────────────────────────

class _OptionsSheet extends StatelessWidget {
  final MediaItem mediaItem;
  const _OptionsSheet({required this.mediaItem});

  @override
  Widget build(BuildContext context) {
    final options = [
      _SheetOption(
          icon: Icons.playlist_add_rounded,
          label: 'Add to Playlist',
          onTap: () => Navigator.pop(context)),
      _SheetOption(
          icon: Icons.lock_rounded,
          label: 'Move to Vault',
          onTap: () => Navigator.pop(context)),
      _SheetOption(
          icon: Icons.share_rounded,
          label: 'Share via Air-Drop',
          onTap: () => Navigator.pop(context)),
      _SheetOption(
          icon: Icons.graphic_eq_rounded,
          label: 'Open in Studio',
          onTap: () => Navigator.pop(context)),
      _SheetOption(
          icon: Icons.info_outline_rounded,
          label: 'File Info',
          onTap: () => Navigator.pop(context)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            mediaItem.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'SpaceGrotesk',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            mediaItem.formattedSize,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ...options.map((o) => ListTile(
                leading: Icon(o.icon, color: AppColors.accent, size: 22),
                title: Text(
                  o.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
                onTap: o.onTap,
                contentPadding: EdgeInsets.zero,
              )),
        ],
      ),
    );
  }
}

class _SheetOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetOption(
      {required this.icon, required this.label, required this.onTap});
}
