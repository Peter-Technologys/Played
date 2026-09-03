import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/services/auto_eq_service.dart';
import '../../../core/services/vault_service.dart';
import '../../../core/services/speed_memory_service.dart';
import '../../../core/services/album_art_service.dart';
import '../../../core/services/audio_handler.dart';
import '../../../core/services/playback_coordinator.dart';
import '../../../core/services/media_notification_service.dart';
import '../../../core/services/new_media_tracker.dart';
import '../../../core/services/sleep_detection_service.dart';
import '../../../shared/widgets/wallpaper_scaffold.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../features/settings/settings_provider.dart';
import 'mini_player.dart';
import 'queue_screen.dart';
import 'lyrics_screen.dart';
import 'file_info_sheet.dart';
import 'car_mode_screen.dart';
import 'widgets/sleep_timer.dart';

enum RepeatState { off, one, all }

class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool isLoading;
  final bool isFavorite;
  final RepeatState repeat;

  const AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.isLoading = true,
    this.isFavorite = false,
    this.repeat = RepeatState.off,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? isLoading,
    bool? isFavorite,
    RepeatState? repeat,
  }) =>
      AudioPlayerState(
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        isLoading: isLoading ?? this.isLoading,
        isFavorite: isFavorite ?? this.isFavorite,
        repeat: repeat ?? this.repeat,
      );
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Otya',
      logLevel: MPVLogLevel.error,
    ),
  );

  String? _currentItemId;
  int _loadGeneration = 0;
  String? _lastNotificationItemId;
  String? _lastResolvedArtPath;

  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completedSub;
  ProviderContainer? _container;

  AudioPlayerNotifier() : super(const AudioPlayerState());

  void init() {
    AudioHandlerSingleton.instance.attachPlayer(_player);
    _attachStreams();
    MediaNotificationService.instance.onSkipPrevious = skipPrevious;
    MediaNotificationService.instance.onSkipNext = skipNext;
    SleepDetectionService.instance.onSleepDetected = () {
      debugPrint('[AudioPlayer] Sleep detected — pausing playback.');
      pause();
    };
  }

  void _attachStreams() {
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      state = state.copyWith(isPlaying: playing);
      if (playing && _currentItemId != null) {
        unawaited(NewMediaTracker.instance.markSeenId(_currentItemId!));
      }
      _updateNotification();
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (buffering && state.duration == Duration.zero) {
        state = state.copyWith(isLoading: true);
      } else if (!buffering) {
        state = state.copyWith(isLoading: false);
      }
    });

    var lastSave = DateTime.fromMillisecondsSinceEpoch(0);
    _positionSub = _player.stream.position.listen((position) {
      if (!mounted) return;
      state = state.copyWith(position: position);
      if (_currentItemId != null && position.inSeconds > 0) {
        final now = DateTime.now();
        if (now.difference(lastSave).inSeconds >= 5) {
          lastSave = now;
          OtyaDatabase.instance.saveSeekPosition(_currentItemId!, position);
        }
      }
    });

    _durationSub = _player.stream.duration.listen((duration) {
      if (!mounted) return;
      state = state.copyWith(duration: duration);
    });

    _completedSub = _player.stream.completed.listen((completed) {
      if (!completed) return;
      if (state.repeat == RepeatState.one) {
        final current = _container?.read(queueProvider).current;
        if (current != null) load(current);
      } else {
        _onTrackComplete();
      }
    });
  }

  void _onTrackComplete() {
    if (_container == null) return;
    final queue = _container!.read(queueProvider);
    final notifier = _container!.read(queueProvider.notifier);
    switch (state.repeat) {
      case RepeatState.one:
        break;
      case RepeatState.all:
        notifier.next();
        final next = _container!.read(queueProvider).current;
        if (next != null) load(next);
        break;
      case RepeatState.off:
        if (queue.currentIndex < queue.items.length - 1) {
          notifier.next();
          final next = _container!.read(queueProvider).current;
          if (next != null) load(next);
        }
        break;
    }
  }

  Future<bool> _loadCurrent(
    MediaItem item, {
    required int generation,
    required double speed,
    Duration? savedPosition,
  }) async {
    bool isCurrent() =>
        _loadGeneration == generation && _currentItemId == item.id;

    try {
      if (!isCurrent()) return false;
      if (_player.state.playing) await _player.pause();
      if (!isCurrent()) return false;

      try {
        await _player.open(Media(item.filePath), play: false);
      } catch (error) {
        debugPrint('[AudioPlayer] player.open failed: $error\nPath: ${item.filePath}');
        if (isCurrent() && mounted) {
          state = state.copyWith(isLoading: false);
        }
        return false;
      }

      if (!isCurrent()) return false;
      await _player.setRate(speed);
      if (!isCurrent()) return false;

      if (savedPosition != null && savedPosition.inSeconds > 0) {
        await _player.seek(savedPosition);
      }
      if (!isCurrent()) return false;

      await PlaybackCoordinator.instance.register(_player, 'audio');
      if (!isCurrent()) return false;
      await _player.play();
      return isCurrent();
    } catch (error) {
      debugPrint('[AudioPlayer] load failed: $error');
      if (isCurrent() && mounted) {
        state = state.copyWith(isLoading: false);
      }
      return false;
    }
  }

  Future<void> load(MediaItem item, {AppSettings? settings}) async {
    final generation = ++_loadGeneration;
    _currentItemId = item.id;
    if (mounted) {
      state = state.copyWith(
        isLoading: true,
        isFavorite: _loadFavorite(item.id),
      );
    }

    final eqPreset = AutoEqService.instance.detectPreset(item.fileName);
    if (eqPreset.name != 'Flat') {
      unawaited(AutoEqService.instance.applyPreset(eqPreset));
    }
    _container?.read(miniPlayerItemProvider.notifier).state = item;
    _updateNotification();

    final saved = OtyaDatabase.instance.getSeekPosition(item.id);

    try {
      final savedSpeed = await SpeedMemoryService.instance.getSpeed(item.id);
      if (_loadGeneration != generation || _currentItemId != item.id) return;
      final speed = savedSpeed ?? settings?.playbackSpeed ?? state.speed;

      final loaded = await _loadCurrent(
        item,
        generation: generation,
        speed: speed,
        savedPosition: saved,
      );
      if (!loaded ||
          _loadGeneration != generation ||
          _currentItemId != item.id) {
        return;
      }

      if (mounted) state = state.copyWith(speed: speed, isLoading: false);
      OtyaDatabase.instance.recordPlay(item).ignore();
    } catch (error) {
      debugPrint('[AudioPlayer] load error: $error');
      if (_loadGeneration == generation &&
          _currentItemId == item.id &&
          mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void _updateNotification() {
    final item = _container?.read(miniPlayerItemProvider);
    if (item == null) return;

    if (item.id == _lastNotificationItemId) {
      MediaNotificationService.instance.show(
        id: item.id,
        title: item.title,
        artist: item.artist ?? 'Unknown Artist',
        isPlaying: state.isPlaying,
        albumArtPath: _lastResolvedArtPath,
      );
      return;
    }

    _lastNotificationItemId = item.id;
    AlbumArtService.instance.resolve(item.albumArtPath).then((resolvedPath) {
      _lastResolvedArtPath = resolvedPath;
      MediaNotificationService.instance.show(
        id: item.id,
        title: item.title,
        artist: item.artist ?? 'Unknown Artist',
        isPlaying: state.isPlaying,
        albumArtPath: resolvedPath,
      );
    });
  }

  bool _loadFavorite(String id) => OtyaDatabase.instance.getFavoriteFlag(id);

  void togglePlay() {
    final willPlay = !state.isPlaying;
    if (willPlay) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  void pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> skipForward() =>
      _player.seek(state.position + const Duration(seconds: 10));

  Future<void> skipBack() {
    final target = state.position - const Duration(seconds: 10);
    return _player.seek(target.isNegative ? Duration.zero : target);
  }

  void skipNext() {
    if (_container == null) return;
    if (_currentItemId != null) {
      OtyaDatabase.instance.saveSeekPosition(_currentItemId!, state.position);
    }
    _container!.read(queueProvider.notifier).next();
    final next = _container!.read(queueProvider).current;
    if (next != null) load(next);
  }

  void skipPrevious() {
    if (state.position.inSeconds > 3) {
      _player.seek(Duration.zero);
      return;
    }
    if (_container == null) return;
    if (_currentItemId != null) {
      OtyaDatabase.instance.saveSeekPosition(_currentItemId!, Duration.zero);
    }
    _container!.read(queueProvider.notifier).previous();
    final previous = _container!.read(queueProvider).current;
    if (previous != null) load(previous);
  }

  void setSpeed(double speed) {
    _player.setRate(speed);
    state = state.copyWith(speed: speed);
    if (_currentItemId != null) {
      SpeedMemoryService.instance.saveSpeed(_currentItemId!, speed);
    }
  }

  void toggleFavorite() {
    final next = !state.isFavorite;
    state = state.copyWith(isFavorite: next);
    if (_currentItemId != null) {
      OtyaDatabase.instance.setFavoriteFlag(_currentItemId!, next);
    }
  }

  void toggleShuffle() {
    _container?.read(queueProvider.notifier).toggleShuffle();
  }

  void cycleRepeat() {
    final next = RepeatState.values[
        (state.repeat.index + 1) % RepeatState.values.length];
    state = state.copyWith(repeat: next);
  }

  void savePosition(String id) =>
      OtyaDatabase.instance.saveSeekPosition(id, state.position);

  @override
  void dispose() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    MediaNotificationService.instance.onSkipPrevious = null;
    MediaNotificationService.instance.onSkipNext = null;
    SleepDetectionService.instance.onSleepDetected = null;
    PlaybackCoordinator.instance.unregister(_player);
    MediaNotificationService.instance.dismiss();
    AudioHandlerSingleton.instance.detachPlayer();
    _player.dispose();
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  final notifier = AudioPlayerNotifier();
  notifier._container = ref.container;
  notifier.init();
  return notifier;
});

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  final bool resumeOnly;

  const AudioPlayerScreen({
    super.key,
    required this.mediaItem,
    this.resumeOnly = false,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with WidgetsBindingObserver {
  bool _showRetry = false;
  Timer? _loadTimeoutTimer;

  void _startLoad() {
    _showRetry = false;
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && ref.read(audioPlayerProvider).isLoading) {
        setState(() => _showRetry = true);
      }
    });
    ref.read(audioPlayerProvider.notifier).load(
          widget.mediaItem,
          settings: ref.read(settingsProvider),
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.resumeOnly) _startLoad();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(audioPlayerProvider.notifier).savePosition(widget.mediaItem.id);
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    ref.read(audioPlayerProvider.notifier).savePosition(widget.mediaItem.id);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showQueue() => showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => const QueueScreen(),
      );

  void _showLyrics(Duration position) => showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => LyricsSheet(item: widget.mediaItem, position: position),
      );

  void _showFileInfo() => showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => FileInfoSheet(item: widget.mediaItem),
      );

  void _showOptions() => showModalBottomSheet(
        context: context,
        useSafeArea: true,
        builder: (_) => _OptionsSheet(
          mediaItem: widget.mediaItem,
          onFileInfo: () {
            Navigator.pop(context);
            _showFileInfo();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final isShuffle = ref.watch(queueProvider.select((queue) => queue.shuffle));
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenHeight < 680;
    final isMedium = screenHeight < 780;
    final isTablet = screenWidth > 600;
    final artPadding = isTablet ? 80.0 : isSmall ? 12.0 : isMedium ? 24.0 : 36.0;
    final playButtonSize = isTablet ? 80.0 : isSmall ? 56.0 : 68.0;
    final skipIconSize = isTablet ? 34.0 : isSmall ? 24.0 : 30.0;
    final spacing = isSmall ? 4.0 : isMedium ? 8.0 : 16.0;

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
                      fontFamily: 'Inter',
                    ),
                  ),
                  const Spacer(),
                  SleepTimerButton(
                    onExpire: () => ref.read(audioPlayerProvider.notifier).pause(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    onPressed: _showOptions,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: artPadding, vertical: 8),
                child: _AlbumArt(
                  albumArtPath: widget.mediaItem.albumArtPath,
                  isPlaying: playerState.isPlaying,
                  title: widget.mediaItem.title,
                  onSwipeLeft: () =>
                      ref.read(audioPlayerProvider.notifier).skipNext(),
                  onSwipeRight: () =>
                      ref.read(audioPlayerProvider.notifier).skipPrevious(),
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
                          widget.mediaItem.title,
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
                          widget.mediaItem.artist ?? 'Unknown Artist',
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
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).toggleFavorite(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        playerState.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(playerState.isFavorite),
                        color: playerState.isFavorite
                            ? Colors.redAccent
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
                onSeek: (position) =>
                    ref.read(audioPlayerProvider.notifier).seek(position),
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
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).toggleShuffle(),
                  ),
                  GestureDetector(
                    onTap: () {
                      const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
                      final index = speeds.indexOf(playerState.speed);
                      ref
                          .read(audioPlayerProvider.notifier)
                          .setSpeed(speeds[(index + 1) % speeds.length]);
                    },
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
                        _formatSpeed(playerState.speed),
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
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).cycleRepeat(),
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
                      ref.read(audioPlayerProvider.notifier).skipPrevious();
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
                      ref.read(audioPlayerProvider.notifier).skipBack();
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_showRetry) {
                        setState(() => _showRetry = false);
                        _startLoad();
                      } else {
                        HapticFeedback.mediumImpact();
                        ref.read(audioPlayerProvider.notifier).togglePlay();
                      }
                    },
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
                      child: playerState.isLoading && !_showRetry
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : _showRetry
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
                      ref.read(audioPlayerProvider.notifier).skipForward();
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
                      ref.read(audioPlayerProvider.notifier).skipNext();
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
                      onTap: () => _showLyrics(playerState.position),
                    ),
                    _SecondaryBtn(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Equalizer',
                      onTap: () => context.push('/player/equalizer'),
                    ),
                    _SecondaryBtn(
                      icon: Icons.queue_music_rounded,
                      label: 'Up Next',
                      onTap: _showQueue,
                    ),
                    _SecondaryBtn(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: () => Share.shareXFiles(
                        [XFile(widget.mediaItem.filePath)],
                        text: widget.mediaItem.title,
                      ),
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

  String _formatSpeed(double speed) => speed == speed.truncateToDouble()
      ? '${speed.toInt()}x'
      : '${speed}x';
}

class _AlbumArt extends StatefulWidget {
  final String? albumArtPath;
  final bool isPlaying;
  final String title;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const _AlbumArt({
    this.albumArtPath,
    required this.isPlaying,
    this.title = '',
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  State<_AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<_AlbumArt> {
  String? _resolvedPath;
  bool _loading = true;
  double _dragX = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_AlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumArtPath != widget.albumArtPath) _resolve();
  }

  Future<void> _resolve() async {
    final path = widget.albumArtPath;
    if (path == null) {
      if (mounted) {
        setState(() {
          _resolvedPath = null;
          _loading = false;
        });
      }
      return;
    }
    if (!path.startsWith('albumid:')) {
      if (mounted) {
        setState(() {
          _resolvedPath = path;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }
    final resolved = await AlbumArtService.instance.resolve(path);
    if (mounted) {
      setState(() {
        _resolvedPath = resolved;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showArt = !_loading && _resolvedPath != null;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() => _dragX += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragX < -60 || velocity < -400) {
          HapticFeedback.mediumImpact();
          widget.onSwipeLeft?.call();
        } else if (_dragX > 60 || velocity > 400) {
          HapticFeedback.mediumImpact();
          widget.onSwipeRight?.call();
        }
        setState(() => _dragX = 0);
      },
      onHorizontalDragCancel: () => setState(() => _dragX = 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_dragX < -20)
            Positioned(
              right: 12,
              child: AnimatedOpacity(
                opacity: (_dragX.abs() / 80).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 80),
                child: const Icon(
                  Icons.skip_next_rounded,
                  color: AppColors.accent,
                  size: 40,
                ),
              ),
            ),
          if (_dragX > 20)
            Positioned(
              left: 12,
              child: AnimatedOpacity(
                opacity: (_dragX.abs() / 80).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 80),
                child: const Icon(
                  Icons.skip_previous_rounded,
                  color: AppColors.accent,
                  size: 40,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragX.clamp(-40.0, 40.0), 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              transform: Matrix4.diagonal3Values(
                widget.isPlaying ? 1.0 : 0.88,
                widget.isPlaying ? 1.0 : 0.88,
                1.0,
              ),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: widget.isPlaying ? 0.35 : 0.1,
                    ),
                    blurRadius: widget.isPlaying ? 48 : 16,
                    spreadRadius: widget.isPlaying ? 6 : 0,
                  ),
                  BoxShadow(
                    color: AppColors.accentViolet.withValues(
                      alpha: widget.isPlaying ? 0.20 : 0.05,
                    ),
                    blurRadius: widget.isPlaying ? 64 : 20,
                    spreadRadius: widget.isPlaying ? 8 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: showArt
                    ? RepaintBoundary(
                        child: Image.file(
                          File(_resolvedPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          cacheWidth: 600,
                        ),
                      )
                    : _DynamicArtPlaceholder(
                        title: widget.title,
                        isPlaying: widget.isPlaying,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicArtPlaceholder extends StatelessWidget {
  final String title;
  final bool isPlaying;

  const _DynamicArtPlaceholder({
    required this.title,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final letter = title.isNotEmpty ? title[0].toUpperCase() : '♪';
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.20),
                AppColors.accentViolet.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(color: Colors.transparent),
        ),
        Center(child: _VinylRing(isPlaying: isPlaying)),
        Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w900,
              color: AppColors.accent.withValues(
                alpha: isPlaying ? 0.95 : 0.60,
              ),
              fontFamily: 'Inter',
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _VinylRing extends StatelessWidget {
  final bool isPlaying;

  const _VinylRing({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.18),
          width: 28,
        ),
      ),
    );

    if (!isPlaying) return ring;
    return ring
        .animate(onPlay: (controller) => controller.repeat())
        .rotate(duration: 4000.ms, curve: Curves.linear);
  }
}

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
            trackHeight: 5,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: progress,
            onChanged: (value) => onSeek(
              Duration(milliseconds: (value * duration.inMilliseconds).toInt()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.format(position),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                DurationFormatter.format(duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleIconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleIconBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Icon(
        icon,
        color: active ? AppColors.accent : AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}

class _RepeatBtn extends StatelessWidget {
  final RepeatState repeat;
  final VoidCallback onTap;

  const _RepeatBtn({required this.repeat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = repeat == RepeatState.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Icon(
        icon,
        color: repeat == RepeatState.off
            ? AppColors.textSecondary
            : AppColors.accent,
        size: 24,
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.accent,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsSheet extends ConsumerWidget {
  final MediaItem mediaItem;
  final VoidCallback onFileInfo;

  const _OptionsSheet({
    required this.mediaItem,
    required this.onFileInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = [
      _Opt(Icons.directions_car_rounded, 'Drive Mode', AppColors.accent, () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CarModeScreen()),
        );
      }),
      _Opt(Icons.playlist_add_rounded, 'Queue It', AppColors.accent, () {
        ref.read(queueProvider.notifier).addToQueue(mediaItem);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Queued!')),
        );
      }),
      _Opt(Icons.lock_rounded, 'Move to Private', AppColors.accentViolet, () async {
        Navigator.pop(context);
        await VaultService.instance.lockItem(mediaItem);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Moved to Private')),
          );
        }
      }),
      _Opt(Icons.send_rounded, 'Transfer', AppColors.accent, () {
        Navigator.pop(context);
        context.go('/transfer');
      }),
      _Opt(Icons.info_outline_rounded, 'Details', AppColors.textSecondary, onFileInfo),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mediaItem.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      mediaItem.formattedSize,
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
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          ...options.map(
            (option) => ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(option.icon, color: option.color, size: 18),
              ),
              title: Text(
                option.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              onTap: option.onTap,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Opt {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Opt(this.icon, this.label, this.color, this.onTap);
}
