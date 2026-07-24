import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/database/played_database.dart';
import '../../../core/services/vault_service.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/services/speed_memory_service.dart';
import '../../../core/services/playback_coordinator.dart';
import '../../../core/services/media_notification_service.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../features/settings/settings_provider.dart';
import 'mini_player.dart';
import 'queue_screen.dart';
// queueProvider and miniPlayerItemProvider are defined in queue_screen.dart
import 'lyrics_screen.dart';
import 'file_info_sheet.dart';
import 'car_mode_screen.dart';
import 'widgets/sleep_timer.dart';

// ── State ──────────────────────────────────────────────────────

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
    bool? isPlaying, Duration? position, Duration? duration,
    double? speed, bool? isLoading, bool? isFavorite,
    RepeatState? repeat,
  }) => AudioPlayerState(
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
  // media_kit Player owned directly — single engine, no audio_service wrapper.
  final Player _player = Player();

  String? _currentItemId;
  bool    _loading        = false;
  int     _loadGeneration = 0;

  // Held subscriptions — cancelled on dispose.
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completedSub;

  // Keep a reference to the ProviderContainer so load() can update
  // miniPlayerItemProvider and read queueProvider without a BuildContext.
  ProviderContainer? _container;

  AudioPlayerNotifier() : super(const AudioPlayerState()) {
    _attachStreams();
  }

  void _attachStreams() {
    // playing stream — reflects actual play/pause state
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      state = state.copyWith(isPlaying: playing);
      _updateNotification();
    });

    // buffering stream — only show spinner during initial load (no duration yet).
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (buffering && state.duration == Duration.zero) {
        state = state.copyWith(isLoading: true);
      } else if (!buffering) {
        state = state.copyWith(isLoading: false);
      }
    });

    // Debounce position saves: write to DB at most once every 5 seconds.
    DateTime lastSave = DateTime.fromMillisecondsSinceEpoch(0);
    _positionSub = _player.stream.position.listen((p) {
      if (!mounted) return;
      state = state.copyWith(position: p);
      if (_currentItemId != null && p.inSeconds > 0) {
        final now = DateTime.now();
        if (now.difference(lastSave).inSeconds >= 5) {
          lastSave = now;
          PlayedDatabase.instance.saveSeekPosition(_currentItemId!, p);
        }
      }
    });

    _durationSub = _player.stream.duration.listen((d) {
      if (!mounted) return;
      state = state.copyWith(duration: d);
    });

    // completed stream — repeat-one reloads current; all other modes call
    // _onTrackComplete() which advances the queue.
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
    final queue    = _container!.read(queueProvider);
    final notifier = _container!.read(queueProvider.notifier);
    switch (state.repeat) {
      case RepeatState.one:
        // Handled directly in _completedSub.
        break;
      case RepeatState.all:
        notifier.next();
        final nextAll = _container!.read(queueProvider).current;
        if (nextAll != null) load(nextAll);
        break;
      case RepeatState.off:
        final hasNext = queue.currentIndex < queue.items.length - 1;
        if (hasNext) {
          notifier.next();
          final nextOff = _container!.read(queueProvider).current;
          if (nextOff != null) load(nextOff);
        }
        break;
    }
  }

  Future<void> _loadCurrent(
    MediaItem item, {
    required double speed,
    Duration? savedPosition,
  }) async {
    _loadGeneration++;
    final myGeneration = _loadGeneration;

    // Reset stale _loading flag instead of returning early (avoids deadlock).
    if (_loading) {
      debugPrint('[AudioPlayer] _loadCurrent: resetting stale _loading flag.');
      _loading = false;
    }
    _loading = true;

    try {
      if (_player.state.playing) await _player.pause();
      if (_loadGeneration != myGeneration) return;

      try {
        await _player.open(Media(item.filePath), play: false);
      } catch (srcErr) {
        debugPrint('[AudioPlayer] player.open failed: $srcErr\nPath: ${item.filePath}');
        if (mounted) state = state.copyWith(isLoading: false);
        return;
      }

      if (_loadGeneration != myGeneration) return;
      await _player.setRate(speed);
      if (_loadGeneration != myGeneration) return;

      if (savedPosition != null && savedPosition.inSeconds > 0) {
        await _player.seek(savedPosition);
      }
      if (_loadGeneration != myGeneration) return;

      await PlaybackCoordinator.instance.register(_player, 'audio');
      await _player.play();
    } catch (e) {
      debugPrint('[AudioPlayer] _loadCurrent error: $e');
      if (mounted) state = state.copyWith(isLoading: false);
    } finally {
      _loading = false;
    }
  }

  Future<void> load(MediaItem item, {AppSettings? settings}) async {
    _currentItemId = item.id;
    if (mounted) {
      state = state.copyWith(isLoading: true, isFavorite: _loadFavorite(item.id));
    }
    _container?.read(miniPlayerItemProvider.notifier).state = item;
    _updateNotification();

    final saved      = PlayedDatabase.instance.getSeekPosition(item.id);
    final savedSpeed = await SpeedMemoryService.instance.getSpeed(item.id);
    final speed      = savedSpeed ?? settings?.playbackSpeed ?? state.speed;

    try {
      await _loadCurrent(item, speed: speed, savedPosition: saved);
      if (mounted) state = state.copyWith(speed: speed, isLoading: false);
      PlayedDatabase.instance.recordPlay(item).ignore();
    } catch (e) {
      debugPrint('[AudioPlayer] load error: $e');
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void _updateNotification() {
    final item = _container?.read(miniPlayerItemProvider);
    if (item == null) return;
    MediaNotificationService.instance.show(
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      isPlaying: state.isPlaying,
      albumArtPath: item.albumArtPath,
    );
  }

  bool _loadFavorite(String id) =>
      PlayedDatabase.instance.getFavoriteFlag(id);

  void togglePlay() {
    final willPlay = !state.isPlaying;
    state = state.copyWith(isPlaying: willPlay);
    if (willPlay) { _player.play(); } else { _player.pause(); }
  }

  void pause() => _player.pause();

  Future<void> seek(Duration p) => _player.seek(p);

  Future<void> skipForward() =>
      _player.seek(state.position + const Duration(seconds: 10));

  Future<void> skipBack() =>
      _player.seek(state.position - const Duration(seconds: 10));

  void skipNext() {
    if (_container == null) return;
    if (_currentItemId != null) {
      PlayedDatabase.instance.saveSeekPosition(_currentItemId!, state.position);
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
      PlayedDatabase.instance.saveSeekPosition(_currentItemId!, Duration.zero);
    }
    _container!.read(queueProvider.notifier).previous();
    final prev = _container!.read(queueProvider).current;
    if (prev != null) load(prev);
  }

  void setSpeed(double s) {
    _player.setRate(s);
    state = state.copyWith(speed: s);
    if (_currentItemId != null) {
      SpeedMemoryService.instance.saveSpeed(_currentItemId!, s);
    }
  }

  void toggleFavorite() {
    final next = !state.isFavorite;
    state = state.copyWith(isFavorite: next);
    if (_currentItemId != null) {
      PlayedDatabase.instance.setFavoriteFlag(_currentItemId!, next);
    }
  }

  void toggleShuffle() {
    _container?.read(queueProvider.notifier).toggleShuffle();
  }

  void cycleRepeat() {
    // Repeat is handled entirely by _completedSub logic.
    // Do NOT call _player.setPlaylistMode() — media_kit's internal playlist
    // mode conflicts with manual queue management.
    final next = RepeatState.values[
        (state.repeat.index + 1) % RepeatState.values.length];
    state = state.copyWith(repeat: next);
  }

  void savePosition(String id) =>
      PlayedDatabase.instance.saveSeekPosition(id, state.position);

  @override
  void dispose() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    PlaybackCoordinator.instance.unregister(_player);
    MediaNotificationService.instance.dismiss();
    _player.dispose();
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) {
    final notifier = AudioPlayerNotifier();
    notifier._container = ref.container;
    return notifier;
  },
);

// ── Screen ─────────────────────────────────────────────────────

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  /// If true, do NOT call load() — just show the UI for the already-playing track.
  /// Used when the mini player taps open the full-screen player without restarting.
  final bool resumeOnly;
  const AudioPlayerScreen({super.key, required this.mediaItem, this.resumeOnly = false});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with WidgetsBindingObserver {

  // Fix A: Track how long we've been in the loading state so we can show
  // a retry button if AudioService never becomes ready.
  DateTime? _loadStartTime;
  bool _showRetry = false;
  Timer? _loadTimeoutTimer;

  void _startLoad() {
    _loadStartTime = DateTime.now();
    _showRetry = false;
    _loadTimeoutTimer?.cancel();
    // After 10 s of continuous loading, surface a retry button.
    _loadTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && ref.read(audioPlayerProvider).isLoading) {
        setState(() => _showRetry = true);
      }
    });
    final settings = ref.read(settingsProvider);
    ref.read(audioPlayerProvider.notifier).load(
      widget.mediaItem,
      settings: settings,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.resumeOnly) {
        // load() already calls PlayedDatabase.instance.recordPlay() internally
        // — do not call it again here to avoid double-counting play history.
        _startLoad();
      }
      // If resumeOnly, the player is already playing — just show the UI.
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
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
    context: context, backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const QueueScreen(),
  );

  void _showLyrics(Duration pos) => showModalBottomSheet(
    context: context, backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => LyricsSheet(item: widget.mediaItem, position: pos),
  );

  void _showFileInfo() => showModalBottomSheet(
    context: context, backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => FileInfoSheet(item: widget.mediaItem),
  );

  void _showOptions() => showModalBottomSheet(
    context: context, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _OptionsSheet(
      mediaItem: widget.mediaItem,
      onFileInfo:        () { Navigator.pop(context); _showFileInfo(); },
      onTrimForWhatsApp: () {
        Navigator.pop(context);
        context.push('/tools/whatsapp', extra: widget.mediaItem);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(audioPlayerProvider);
    // Shuffle state is owned by QueueNotifier — single source of truth.
    final isShuffle = ref.watch(queueProvider.select((q) => q.shuffle));
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenHeight < 680;
    final isMedium = screenHeight < 780;
    final isTablet = screenWidth > 600;
    final artPadding = isTablet ? 80.0 : isSmall ? 12.0 : isMedium ? 24.0 : 36.0;
    final playBtnSize = isTablet ? 80.0 : isSmall ? 56.0 : 68.0;
    final skipIconSize = isTablet ? 34.0 : isSmall ? 24.0 : 30.0;
    final vSpace = isSmall ? 4.0 : isMedium ? 8.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Theme.of(context).colorScheme.onSurface, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text('NOW PLAYING',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.5, fontFamily: 'Inter',
                      )),
                  const Spacer(),
                  SleepTimerButton(
                    onExpire: () =>
                        ref.read(audioPlayerProvider.notifier).pause(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.textSecondary, size: 22),
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
                  isPlaying: ps.isPlaying,
                ),
              ),
            ),
            SizedBox(height: vSpace),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.mediaItem.title,
                            style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(widget.mediaItem.artist ?? 'Unknown Artist',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary,
                                fontFamily: 'Inter'),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).toggleFavorite(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        ps.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(ps.isFavorite),
                        color: ps.isFavorite
                            ? Colors.redAccent
                            : AppColors.textSecondary,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: vSpace),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SeekBar(
                position: ps.position,
                duration: ps.duration,
                onSeek: (d) =>
                    ref.read(audioPlayerProvider.notifier).seek(d),
              ),
            ),
            SizedBox(height: vSpace / 2),
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
                      final idx = speeds.indexOf(ps.speed);
                      ref.read(audioPlayerProvider.notifier)
                          .setSpeed(speeds[(idx + 1) % speeds.length]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Text(
                          _formatSpeed(ps.speed),
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            fontFamily: 'Inter',
                          )),
                    ),
                  ),
                  _RepeatBtn(
                    repeat: ps.repeat,
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).cycleRepeat(),
                  ),
                ],
              ),
            ),
            SizedBox(height: vSpace / 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded,
                        color: Theme.of(context).colorScheme.onSurface, size: skipIconSize),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(audioPlayerProvider.notifier).skipPrevious();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.replay_10_rounded,
                        color: Theme.of(context).colorScheme.onSurface, size: skipIconSize),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(audioPlayerProvider.notifier).skipBack();
                    },
                  ),
      // Gradient play button (doubles as retry button when load timed out)
                  GestureDetector(
                    onTap: () {
                      if (_showRetry) {
                        // Fix A: Retry loading when AudioService was not ready.
                        setState(() => _showRetry = false);
                        _startLoad();
                      } else {
                        HapticFeedback.mediumImpact();
                        ref.read(audioPlayerProvider.notifier).togglePlay();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: playBtnSize, height: playBtnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentViolet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.45),
                            blurRadius: 28, spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: AppColors.accentViolet.withValues(alpha: 0.25),
                            blurRadius: 60, spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: ps.isLoading && !_showRetry
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : _showRetry
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Icon(Icons.refresh_rounded,
                                      color: Colors.black, size: 30))
                              : Icon(
                                  ps.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black, size: 38,
                                ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.forward_10_rounded,
                        color: Theme.of(context).colorScheme.onSurface, size: skipIconSize),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(audioPlayerProvider.notifier).skipForward();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded,
                        color: Theme.of(context).colorScheme.onSurface, size: skipIconSize),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(audioPlayerProvider.notifier).skipNext();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: vSpace),
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
                      onTap: () => _showLyrics(ps.position),
                    ),
                    _SecondaryBtn(
                      icon: Icons.graphic_eq_rounded,
                      label: 'EQ',
                      onTap: () => context.push('/player/equalizer'),
                    ),
                    _SecondaryBtn(
                      icon: Icons.queue_music_rounded,
                      label: 'Queue',
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

  String _formatSpeed(double speed) {
    if (speed == speed.truncateToDouble()) {
      return '${speed.toInt()}x';
    }
    return '${speed}x';
  }
}

// ── Album Art ──────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final String? albumArtPath;
  final bool isPlaying;
  const _AlbumArt({this.albumArtPath, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      transform: Matrix4.diagonal3Values(
          isPlaying ? 1.0 : 0.88,
          isPlaying ? 1.0 : 0.88,
          1.0),
      transformAlignment: Alignment.center,
      // AnimatedScale delegates the transform to the compositor so the
      // easing curve is applied correctly without a Dart-side rebuild per frame.
      // Wrapping AnimatedContainer so shadow also animates.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: isPlaying ? 0.35 : 0.1),
            blurRadius: isPlaying ? 48 : 16,
            spreadRadius: isPlaying ? 6 : 0,
          ),
          BoxShadow(
            color: AppColors.accentViolet.withValues(alpha: isPlaying ? 0.20 : 0.05),
            blurRadius: isPlaying ? 64 : 20,
            spreadRadius: isPlaying ? 8 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: albumArtPath != null && !albumArtPath!.startsWith('albumid:')
            ? Image.file(File(albumArtPath!),
                fit: BoxFit.cover, width: double.infinity)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.15),
                      AppColors.accentViolet.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppColors.accent.withValues(
                        alpha: isPlaying ? 0.9 : 0.5),
                    size: 80,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Seek Bar ───────────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  const _SeekBar(
      {required this.position, required this.duration, required this.onSeek});

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
            onChanged: (v) => onSeek(
                Duration(milliseconds: (v * duration.inMilliseconds).toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DurationFormatter.format(position),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text(DurationFormatter.format(duration),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Toggle Icon Button ─────────────────────────────────────────

class _ToggleIconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToggleIconBtn(
      {required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Icon(icon,
          color: active ? AppColors.accent : AppColors.textSecondary,
          size: 24),
    );
  }
}

// ── Repeat Button ──────────────────────────────────────────────

class _RepeatBtn extends StatelessWidget {
  final RepeatState repeat;
  final VoidCallback onTap;
  const _RepeatBtn({required this.repeat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = repeat == RepeatState.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    final active = repeat != RepeatState.off;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Icon(icon,
          color: active ? AppColors.accent : AppColors.textSecondary,
          size: 24),
    );
  }
}

// ── Secondary Button ───────────────────────────────────────────

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                fontSize: 10, color: AppColors.accent,
                fontFamily: 'Inter', fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

// ── Options Sheet ──────────────────────────────────────────────

class _OptionsSheet extends ConsumerWidget {
  final MediaItem mediaItem;
  final VoidCallback onFileInfo;
  final VoidCallback onTrimForWhatsApp;
  const _OptionsSheet({
    required this.mediaItem,
    required this.onFileInfo,
    required this.onTrimForWhatsApp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = [
      _Opt(Icons.directions_car_rounded, 'Car Mode', AppColors.accent, () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CarModeScreen()),
        );
      }),
      _Opt(Icons.playlist_add_rounded, 'Add to Playlist', AppColors.accent, () {
        ref.read(queueProvider.notifier).addToQueue(mediaItem);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to queue')));
      }),
      _Opt(Icons.lock_rounded, 'Move to Vault', AppColors.accentViolet, () async {
        Navigator.pop(context);
        await VaultService.instance.lockItem(mediaItem);
        if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Moved to Vault'))); }
      }),
      _Opt(Icons.wifi_tethering_rounded, 'Share via Air-Drop', AppColors.accent, () {
        Navigator.pop(context);
        context.go('/airdrop');
      }),
      _Opt(Icons.phone_android_rounded, 'Trim for WhatsApp',   AppColors.accent, onTrimForWhatsApp),
      _Opt(Icons.download_rounded, 'Extract Audio (MP3)', AppColors.accent, () async {
        Navigator.pop(context);
        await FfmpegService.instance.extractAudio(
            videoPath: mediaItem.filePath, onProgress: (_) {});
        if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio extracted to Downloads'))); }
      }),
      _Opt(Icons.info_outline_rounded, 'File Info', AppColors.textSecondary, onFileInfo),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.music_note_rounded,
                    color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mediaItem.title,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(mediaItem.formattedSize,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          ...options.map((o) => ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: o.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(o.icon, color: o.color, size: 18),
                ),
                title: Text(o.label,
                    style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    )),
                // All _Opt instances have non-null onTap; call directly.
                onTap: o.onTap,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                dense: true,
              )),
        ],
      ),
    );
  }
}

class _Opt {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Opt(this.icon, this.label, this.color, this.onTap);
}
