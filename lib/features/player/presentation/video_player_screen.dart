import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/services/media_kit_engine.dart';
import '../../../core/services/native_share_service.dart';
import '../../../core/services/pip_service.dart';
import '../../../core/services/playback_coordinator.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../features/player/presentation/widgets/video_gesture_layer.dart';
import '../../../features/settings/settings_provider.dart';
import 'queue_screen.dart';
import '../../../shared/widgets/speed_picker_sheet.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;

  const VideoPlayerScreen({super.key, required this.mediaItem});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  bool _pipSupported = false;
  bool _pipAutoEnabled = false;
  bool _pipInitialized = false;
  late final Duration _savedPosition;

  bool _controlsVisible = true;
  bool _isLocked = false;
  bool _isMuted = false;
  bool _ccEnabled = false;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  int _aspectRatioIndex = 0;
  bool _isPlaying = true;
  bool _isSeeking = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Player? _player;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;

  static const _aspectRatioLabels = [
    'Fit to Screen',
    'Center Crop',
    'Stretch',
  ];
  static const _aspectRatioFits = [
    BoxFit.contain,
    BoxFit.cover,
    BoxFit.fill,
  ];

  @override
  void initState() {
    super.initState();
    _savedPosition =
        OtyaDatabase.instance.getSeekPosition(widget.mediaItem.id) ??
            Duration.zero;
    _position = _savedPosition;
    WidgetsBinding.instance.addObserver(this);
    _initOrientationFromVideo();
    _initPip();
    _resetHideTimer();
  }

  Future<void> _initPip() async {
    _pipSupported = await PipService.instance.isPipSupported();
    _pipAutoEnabled = ref.read(settingsProvider).autoPip;
    await PipService.instance.setVideoPlaying(playing: _isPlaying);
    _pipInitialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _position > Duration.zero) {
      OtyaDatabase.instance.saveSeekPosition(widget.mediaItem.id, _position);
    }
    if (!_pipInitialized) return;
    if (state == AppLifecycleState.paused &&
        _pipAutoEnabled &&
        _pipSupported &&
        _isPlaying) {
      PipService.instance.enterPip();
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isLocked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _initOrientationFromVideo() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _lockToLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _lockToPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _toggleOrientation() async {
    HapticFeedback.selectionClick();
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (landscape) {
      await _lockToPortrait();
    } else {
      await _lockToLandscape();
    }
  }

  Future<void> _restoreOrientation() async {
    await PipService.instance.setVideoPlaying(playing: false);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String get size {
    final bytes = widget.mediaItem.fileSizeBytes;
    if (bytes == 0) return 'Unknown';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _toggleSubtitles() async {
    final player = _player;
    if (player == null) return;

    HapticFeedback.selectionClick();
    if (_ccEnabled) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      if (mounted) setState(() => _ccEnabled = false);
      return;
    }

    final tracks = player.state.tracks.subtitle;
    if (tracks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No embedded subtitles found'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
      return;
    }

    await player.setSubtitleTrack(tracks.first);
    if (mounted) setState(() => _ccEnabled = true);
  }

  Future<void> _shareMedia() async {
    try {
      await NativeShareService.shareFile(
        path: widget.mediaItem.filePath,
        text: widget.mediaItem.title,
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTYA could not share that file.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
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
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.share_rounded,
                color: AppColors.accentGreen,
                size: 22,
              ),
              title: const Text(
                'Share',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _shareMedia();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              title: const Text(
                'Details',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text(
                      'Details',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Title', value: widget.mediaItem.title),
                        _InfoRow(label: 'Path', value: widget.mediaItem.filePath),
                        _InfoRow(label: 'Size', value: size),
                        _InfoRow(
                          label: 'Duration',
                          value: widget.mediaItem.formattedDuration,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.audiotrack_rounded,
                color: AppColors.accentViolet,
                size: 22,
              ),
              title: const Text(
                'Extract Audio',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Extracting audio…'),
                    duration: Duration(seconds: 30),
                    backgroundColor: AppColors.surface,
                  ),
                );
                final result = await FfmpegService.instance.extractAudio(
                  videoPath: widget.mediaItem.filePath,
                );
                messenger.hideCurrentSnackBar();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result != null
                          ? 'Audio saved: $result'
                          : 'Failed to extract audio',
                    ),
                    backgroundColor:
                        result != null ? AppColors.surface : AppColors.error,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.content_cut_rounded,
                color: AppColors.accentAmber,
                size: 22,
              ),
              title: const Text(
                'Trim Video',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push('/tools/whatsapp', extra: widget.mediaItem);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedPicker() {
    HapticFeedback.selectionClick();
    showSpeedPickerSheet(
      context: context,
      currentSpeed: _playbackSpeed,
      onSpeedSelected: (speed) {
        setState(() => _playbackSpeed = speed);
        _player?.setRate(speed);
      },
    );
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 16),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Text(
                        widget.mediaItem.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.mediaItem.filePath.toLowerCase().contains('hdr'))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.cyanAccent,
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HDR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.cyanAccent,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.closed_caption_rounded,
                        color:
                            _ccEnabled ? AppColors.accent : Colors.white70,
                        size: 20,
                      ),
                      tooltip: _ccEnabled ? 'Turn subtitles off' : 'Turn subtitles on',
                      onPressed: _toggleSubtitles,
                    ),
                    IconButton(
                      tooltip: 'Audio tracks',
                      icon: const Icon(
                        Icons.audiotrack_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final player = _player;
                        if (player == null) return;
                        final audioTracks = player.state.tracks.audio;
                        if (audioTracks.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No other audio tracks'),
                              backgroundColor: AppColors.surface,
                            ),
                          );
                          return;
                        }
                        showModalBottomSheet(
                          context: context,
                          useSafeArea: true,
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          builder: (_) => _AudioTrackSheet(
                            tracks: audioTracks,
                            activeTrack: player.state.track.audio,
                            onSelect: player.setAudioTrack,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Equalizer',
                      icon: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push('/player/equalizer');
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _showMoreOptions();
                      },
                      tooltip: 'More options',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: 0,
          bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: _isMuted ? 'Unmute' : 'Mute',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isMuted = !_isMuted);
                  _player?.setVolume(_isMuted ? 0 : 100);
                },
                icon: Icon(
                  _isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: 'Lock controls',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isLocked = true);
                  _hideTimer?.cancel();
                },
                icon: const Icon(
                  Icons.lock_open_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 4,
          top: 0,
          bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Rotate screen',
                onPressed: _toggleOrientation,
                icon: const Icon(
                  Icons.screen_rotation_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: 'Screenshot help',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Use your device\'s power + volume-down buttons to screenshot',
                      ),
                      backgroundColor: AppColors.surface,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: 'Trim video',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push('/tools/whatsapp', extra: widget.mediaItem);
                },
                icon: const Icon(
                  Icons.content_cut_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black54],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          DurationFormatter.format(_position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              activeTrackColor: AppColors.accent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppColors.accent,
                              overlayColor:
                                  AppColors.accent.withValues(alpha: 0.2),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              value: _position.inSeconds.toDouble().clamp(
                                    0,
                                    _duration.inSeconds
                                        .toDouble()
                                        .clamp(1, double.infinity),
                                  ),
                              max: _duration.inSeconds
                                  .toDouble()
                                  .clamp(1, double.infinity),
                              onChangeStart: (_) =>
                                  setState(() => _isSeeking = true),
                              onChanged: (value) => setState(
                                () => _position =
                                    Duration(seconds: value.toInt()),
                              ),
                              onChangeEnd: (value) {
                                _player?.seek(
                                  Duration(seconds: value.toInt()),
                                );
                                setState(() => _isSeeking = false);
                              },
                            ),
                          ),
                        ),
                        Text(
                          DurationFormatter.format(_duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          tooltip: 'Back 10 seconds',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            final next =
                                _position - const Duration(seconds: 10);
                            final position =
                                next < Duration.zero ? Duration.zero : next;
                            _player?.seek(position);
                            setState(() => _position = position);
                          },
                          icon: const Icon(
                            Icons.replay_10_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Previous',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(queueProvider.notifier).previous();
                            final previous = ref.read(queueProvider).current;
                            if (previous != null && context.mounted) {
                              Navigator.of(context).pop();
                              context.push('/player/video', extra: previous);
                            }
                          },
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: _isPlaying ? 'Pause' : 'Play',
                          constraints: const BoxConstraints(
                            minWidth: 56,
                            minHeight: 56,
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            if (_isPlaying) {
                              _player?.pause();
                            } else {
                              _player?.play();
                            }
                          },
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: AppColors.accent,
                            size: 52,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Next',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(queueProvider.notifier).next();
                            final next = ref.read(queueProvider).current;
                            if (next != null && context.mounted) {
                              Navigator.of(context).pop();
                              context.push('/player/video', extra: next);
                            }
                          },
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Forward 10 seconds',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            final next =
                                _position + const Duration(seconds: 10);
                            final position =
                                next > _duration ? _duration : next;
                            _player?.seek(position);
                            setState(() => _position = position);
                          },
                          icon: const Icon(
                            Icons.forward_10_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _showSpeedPicker,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            side: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: _aspectRatioLabels[_aspectRatioIndex],
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _aspectRatioIndex =
                                  (_aspectRatioIndex + 1) %
                                      _aspectRatioFits.length,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _aspectRatioLabels[_aspectRatioIndex],
                                ),
                                backgroundColor: AppColors.surface,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.aspect_ratio_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Picture in picture',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (_pipSupported) {
                              PipService.instance.enterPip();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pop-up not supported'),
                                  backgroundColor: AppColors.surface,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.picture_in_picture_alt_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockOverlay() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Center(
        child: Semantics(
          button: true,
          label: 'Unlock video controls',
          child: InkWell(
            borderRadius: BorderRadius.circular(48),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isLocked = false);
              _resetHideTimer();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 68,
                    minHeight: 68,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap to unlock',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _attachPlayer(Player player) {
    if (_player == player) return;
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _player = player;

    _positionSub = player.stream.position.listen((position) {
      if (mounted && !_isSeeking) setState(() => _position = position);
    });
    _durationSub = player.stream.duration.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _playingSub = player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
      if (_pipInitialized) {
        unawaited(PipService.instance.setVideoPlaying(playing: playing));
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    if (_player != null) {
      PlaybackCoordinator.instance.unregister(_player!);
    }
    Future.microtask(_restoreOrientation);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          VideoGestureLayer(
            onSeek: (delta) {
              if (_player == null) return;
              final next = _position + delta;
              final position = next < Duration.zero
                  ? Duration.zero
                  : (next > _duration ? _duration : next);
              _player!.seek(position);
              if (mounted) setState(() => _position = position);
            },
            child: MediaKitEngine(
              filePath: widget.mediaItem.filePath,
              title: widget.mediaItem.title,
              startPosition: _savedPosition,
              autoPlay: true,
              fit: _aspectRatioFits[_aspectRatioIndex],
              onPlayerReady: _attachPlayer,
            ),
          ),
          if (!_controlsVisible && !_isLocked)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _resetHideTimer,
                child: const SizedBox.expand(),
              ),
            ),
          if (!_isLocked)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _resetHideTimer,
                  child: _buildControlsOverlay(),
                ),
              ),
            ),
          if (_isLocked) _buildLockOverlay(),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioTrackSheet extends StatelessWidget {
  final List<AudioTrack> tracks;
  final AudioTrack activeTrack;
  final void Function(AudioTrack) onSelect;

  const _AudioTrackSheet({
    required this.tracks,
    required this.activeTrack,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const Text(
            'Audio Track',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          ...tracks.map((track) {
            final active = track.id == activeTrack.id;
            final label = track.language?.isNotEmpty == true
                ? track.language!
                : track.title?.isNotEmpty == true
                    ? track.title!
                    : 'Track ${tracks.indexOf(track) + 1}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                active
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: active ? AppColors.accent : AppColors.textSecondary,
                size: 20,
              ),
              title: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  color: active ? AppColors.accent : AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onSelect(track);
              },
            );
          }),
        ],
      ),
    );
  }
}
