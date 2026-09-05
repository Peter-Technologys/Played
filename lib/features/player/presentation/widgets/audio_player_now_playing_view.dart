part of '../audio_player_screen.dart';

class _AudioPlayerNowPlayingView extends StatelessWidget {
  final MediaItem activeItem;
  final AudioPlayerState playerState;
  final bool isShuffle;
  final bool showRetry;
  final double artPadding;
  final double playButtonSize;
  final double skipIconSize;
  final double spacing;
  final String speedLabel;
  final VoidCallback onBack;
  final VoidCallback onSleepExpire;
  final VoidCallback onOptions;
  final VoidCallback onSwipeNext;
  final VoidCallback onSwipePrevious;
  final VoidCallback onFavorite;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onShuffle;
  final VoidCallback onSpeed;
  final VoidCallback onRepeat;
  final VoidCallback onPrevious;
  final VoidCallback onSkipBack;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onEqualizer;
  final VoidCallback onQueue;
  final VoidCallback onShare;

  const _AudioPlayerNowPlayingView({
    required this.activeItem,
    required this.playerState,
    required this.isShuffle,
    required this.showRetry,
    required this.artPadding,
    required this.playButtonSize,
    required this.skipIconSize,
    required this.spacing,
    required this.speedLabel,
    required this.onBack,
    required this.onSleepExpire,
    required this.onOptions,
    required this.onSwipeNext,
    required this.onSwipePrevious,
    required this.onFavorite,
    required this.onSeek,
    required this.onShuffle,
    required this.onSpeed,
    required this.onRepeat,
    required this.onPrevious,
    required this.onSkipBack,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onNext,
    required this.onLyrics,
    required this.onEqualizer,
    required this.onQueue,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return WallpaperScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 30,
                    ),
                    onPressed: onBack,
                  ),
                  const Spacer(),
                  const Text(
                    'NOW PLAYING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const Spacer(),
                  SleepTimerButton(onExpire: onSleepExpire),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    onPressed: onOptions,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: artPadding,
                  vertical: 8,
                ),
                child: _AlbumArt(
                  albumArtPath: activeItem.albumArtPath,
                  isPlaying: playerState.isPlaying,
                  title: activeItem.title,
                  onSwipeLeft: onSwipeNext,
                  onSwipeRight: onSwipePrevious,
                ),
              ),
            ),
            SizedBox(height: spacing),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeItem.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeItem.artist ?? 'Unknown Artist',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onFavorite,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        playerState.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(playerState.isFavorite),
                        color: playerState.isFavorite
                            ? AppColors.brandRed
                            : AppColors.textSecondary,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SeekBar(
                position: playerState.position,
                duration: playerState.duration,
                onSeek: onSeek,
              ),
            ),
            SizedBox(height: spacing / 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ToggleIconBtn(
                    icon: Icons.shuffle_rounded,
                    active: isShuffle,
                    onTap: onShuffle,
                  ),
                  GestureDetector(
                    onTap: onSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Text(
                        speedLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  _RepeatBtn(
                    repeat: playerState.repeat,
                    onTap: onRepeat,
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing / 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: skipIconSize,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onPrevious();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.replay_10_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: skipIconSize,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onSkipBack();
                    },
                  ),
                  GestureDetector(
                    onTap: onPlayPause,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: playButtonSize,
                      height: playButtonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.24),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: playerState.isLoading && !showRetry
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : showRetry
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                )
                              : Icon(
                                  playerState.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.forward_10_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: skipIconSize,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onSkipForward();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: skipIconSize,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onNext();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SecondaryBtn(
                      icon: Icons.lyrics_rounded,
                      label: 'Lyrics',
                      onTap: onLyrics,
                    ),
                    _SecondaryBtn(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Equalizer',
                      onTap: onEqualizer,
                    ),
                    _SecondaryBtn(
                      icon: Icons.queue_music_rounded,
                      label: 'Up Next',
                      onTap: onQueue,
                    ),
                    _SecondaryBtn(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: onShare,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
