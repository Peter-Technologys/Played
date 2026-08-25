import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/services/media_kit_engine.dart';
import '../../../core/services/pip_service.dart';
import '../../../core/services/playback_coordinator.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../features/player/presentation/widgets/video_gesture_layer.dart';
import '../../../features/settings/settings_provider.dart';
import 'file_info_sheet.dart';
import 'queue_screen.dart';
import '../../../shared/widgets/speed_picker_sheet.dart';

final batterySaverProvider    = StateProvider<bool>((_) => false);
final controlsVisibleProvider = StateProvider<bool>((_) => true);

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  const VideoPlayerScreen({super.key, required this.mediaItem});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  // ── PiP / orientation ──────────────────────────────────────────────
  bool _pipSupported    = false;
  bool _pipAutoEnabled  = false;
  bool _pipInitialized  = false;
  bool _batterySaver    = false;
  bool _isLandscape     = false;
  late final Duration _savedPosition;

  // ── Overlay state ──────────────────────────────────────────────────
  bool _controlsVisible = true;
  bool _isLocked        = false;
  bool _isMuted         = false;
  bool _ccEnabled       = false;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  int _aspectRatioIndex = 0; // 0=Fit, 1=CenterCrop, 2=Stretch
  bool _isPlaying       = true;
  bool _isSeeking       = false;
  Duration _position    = Duration.zero;
  Duration _duration    = Duration.zero;

  // ── MediaKit player reference (set by MediaKitEngine callback) ─────
  Player? _player;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;

  static const _aspectRatioLabels = ['Fit to Screen', 'Center Crop', 'Stretch'];

  static const _aspectRatioFits = [BoxFit.contain, BoxFit.cover, BoxFit.fill];

  @override
  void initState() {
    super.initState();
    _savedPosition =
        OtyaDatabase.instance.getSeekPosition(widget.mediaItem.id) ??
        Duration.zero;
    // Initialise _position from _savedPosition so the seek bar shows the
    // correct position immediately, before the first stream event arrives.
    _position = _savedPosition;
    WidgetsBinding.instance.addObserver(this);
    _initOrientationFromVideo();
    _initPip();
    _resetHideTimer();
  }

  Future<void> _initPip() async {
    _pipSupported   = await PipService.instance.isPipSupported();
    _pipAutoEnabled = ref.read(settingsProvider).autoPip;
    await PipService.instance.setVideoPlaying(playing: true);
    _pipInitialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fix #20: Persist seek position when the app is backgrounded or killed
    // so the user can resume from where they left off after an app restart.
    if (state == AppLifecycleState.paused) {
      if (_position > Duration.zero) {
        OtyaDatabase.instance
            .saveSeekPosition(widget.mediaItem.id, _position);
      }
    }
    if (!_pipInitialized) return;
    if (state == AppLifecycleState.paused && _pipAutoEnabled && _pipSupported) {
      PipService.instance.enterPip();
    }
  }

  // ── Auto-hide logic ────────────────────────────────────────────────

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

  // ── Orientation helpers ────────────────────────────────────────────

  /// Never force orientation — unlock all and let the device/user decide.
  /// The user can still toggle orientation manually with the button.
  Future<void> _initOrientationFromVideo() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _lockToLandscape() async {
    _isLandscape = true;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _lockToPortrait() async {
    _isLandscape = false;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _toggleOrientation() async {
    HapticFeedback.selectionClick();
    // TASK 6: Read actual orientation from MediaQuery instead of relying on
    // the potentially stale _isLandscape field (which can be wrong after
    // auto-rotation or when the user rotates the device manually).
    final isCurrentlyLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isCurrentlyLandscape) {
      await _lockToPortrait();
    } else {
      await _lockToLandscape();
    }
    if (mounted) setState(() {});
  }

  Future<void> _restoreOrientation() async {
    await PipService.instance.setVideoPlaying(playing: false);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── More options ───────────────────────────────────────────────

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            // Share
            ListTile(
              leading: const Icon(Icons.share_rounded,
                  color: AppColors.accentGreen, size: 22),
              title: const Text('Share',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.pop(context);
                await Share.shareXFiles(
                  [XFile(widget.mediaItem.filePath)],
                  text: widget.mediaItem.title,
                );
              },
            ),
            // File Info — uses the shared FileInfoSheet widget
            ListTile(
              leading: const Icon(Icons.info_outline_rounded,
                  color: AppColors.accent, size: 22),
              title: const Text('Details',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Details',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Title', value: widget.mediaItem.title),
                        _InfoRow(label: 'Path', value: widget.mediaItem.filePath),
                        _InfoRow(label: 'Size', value: size),
                        _InfoRow(
                            label: 'Duration',
                            value: widget.mediaItem.formattedDuration),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close',
                            style: TextStyle(color: AppColors.accent)),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Extract Audio
            ListTile(
              leading: const Icon(Icons.audiotrack_rounded,
                  color: AppColors.accentViolet, size: 22),
              title: const Text('Rip Audio',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Extracting audio…'),
                  duration: Duration(seconds: 30),
                  backgroundColor: AppColors.surface,
                ));
                final result = await FfmpegService.instance.extractAudio(
                  videoPath: widget.mediaItem.filePath,
                );
                messenger.hideCurrentSnackBar();
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text(result != null
                      ? 'Audio saved: $result'
                      : 'Failed to extract audio'),
                  backgroundColor:
                      result != null ? AppColors.surface : AppColors.error,
                ));
              },
            ),
            // Trim for WhatsApp
            ListTile(
              leading: const Icon(Icons.content_cut_rounded,
                  color: AppColors.accentAmber, size: 22),
              title: const Text('Trim',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500)),
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

  // ── Speed picker ───────────────────────────────────────────────────

  void _showSpeedPicker() {
    HapticFeedback.selectionClick();
    showSpeedPickerSheet(
      context: context,
      currentSpeed: _playbackSpeed,
      onSpeedSelected: (s) {
        setState(() => _playbackSpeed = s);
        _player?.setRate(s);
      },
    );
  }

  // ── Overlay builders ───────────────────────────────────────────────

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
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
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                    ),
                    // Title
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
                    // HDR badge — only shown when filename contains 'hdr'
                    if (widget.mediaItem.filePath.toLowerCase().contains('hdr'))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.cyanAccent, width: 0.8),
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
                    // CC toggle
                    IconButton(
                      icon: Icon(
                        Icons.closed_caption_rounded,
                        color: _ccEnabled
                            ? AppColors.accent
                            : Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _ccEnabled = !_ccEnabled);
                      },
                    ),
                    // Audio track button
                    IconButton(
                      icon: const Icon(Icons.audiotrack_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (_player == null) return;
                        final audioTracks = _player!.state.tracks.audio;
                        if (audioTracks.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other audio tracks'), backgroundColor: AppColors.surface));
                          return;
                        }
                        showModalBottomSheet(
                          context: context,
                          useSafeArea: true,
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                          builder: (_) => _AudioTrackSheet(tracks: audioTracks, activeTrack: _player!.state.track.audio, onSelect: (t) => _player!.setAudioTrack(t)),
                        );
                      },
                    ),
                    // Equalizer shortcut
                    IconButton(
                      icon: const Icon(Icons.graphic_eq_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push('/player/equalizer');
                      },
                    ),
                    // More options
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Colors.white70, size: 22),
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

        // Left side controls
        Positioned(
          left: 12, top: 0, bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mute/Unmute
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isMuted = !_isMuted);
                  _player?.setVolume(_isMuted ? 0 : 100);
                },
                child: Icon(
                  _isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              // Lock
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isLocked = true);
                  _hideTimer?.cancel();
                },
                child: const Icon(Icons.lock_open_rounded,
                    color: Colors.white70, size: 24),
              ),
            ],
          ),
        ),

        // Right side controls
        Positioned(
          right: 12, top: 0, bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Orientation lock
              GestureDetector(
                onTap: _toggleOrientation,
                child: const Icon(Icons.screen_rotation_rounded,
                    color: Colors.white70, size: 24),
              ),
              const SizedBox(height: 16),
              // Screenshot button
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Use your device\'s power + volume-down buttons to screenshot'),
                      backgroundColor: AppColors.surface,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white70, size: 24),
              ),
              const SizedBox(height: 16),
              // Video cutter
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/tools/whatsapp', extra: widget.mediaItem);
                },
                child: const Icon(Icons.content_cut_rounded,
                    color: Colors.white70, size: 24),
              ),
            ],
          ),
        ),

        // Bottom control bar
        Positioned(
          bottom: 0, left: 0, right: 0,
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
                    // Row 1 — Seek bar
                    Row(
                      children: [
                        Text(
                          DurationFormatter.format(_position),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'Inter'),
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
                                  enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: _position.inSeconds.toDouble(),
                              max: _duration.inSeconds
                                  .toDouble()
                                  .clamp(1, double.infinity),
                              onChangeStart: (_) =>
                                  setState(() => _isSeeking = true),
                              onChanged: (v) => setState(
                                  () => _position = Duration(seconds: v.toInt())),
                              onChangeEnd: (v) {
                                _player?.seek(Duration(seconds: v.toInt()));
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
                              fontFamily: 'Inter'),
                        ),
                      ],
                    ),

                    // Row 2 — Transport controls
                    Row(
                      children: [
                        const Spacer(),
                        // Skip back 10s
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final newPos = _position - const Duration(seconds: 10);
                            final clamped = newPos < Duration.zero ? Duration.zero : newPos;
                            _player?.seek(clamped);
                            setState(() => _position = clamped);
                          },
                          child: const Icon(Icons.replay_10_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        // Previous track
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(queueProvider.notifier).previous();
                            final prev = ref.read(queueProvider).current;
                            if (prev != null && context.mounted) {
                              Navigator.of(context).pop();
                              context.push('/player/video', extra: prev);
                            }
                          },
                          child: const Icon(Icons.skip_previous_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        // Play/Pause
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (_isPlaying) {
                              _player?.pause();
                              setState(() => _isPlaying = false);
                            } else {
                              _player?.play();
                              setState(() => _isPlaying = true);
                            }
                          },
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: AppColors.accent,
                            size: 52,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Next track
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(queueProvider.notifier).next();
                            final next = ref.read(queueProvider).current;
                            if (next != null && context.mounted) {
                              Navigator.of(context).pop();
                              context.push('/player/video', extra: next);
                            }
                          },
                          child: const Icon(Icons.skip_next_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        // Skip forward 10s
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final newPos = _position + const Duration(seconds: 10);
                            final clamped = newPos > _duration ? _duration : newPos;
                            _player?.seek(clamped);
                            setState(() => _position = clamped);
                          },
                          child: const Icon(Icons.forward_10_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const Spacer(),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Row 3 — Extra controls
                    Row(
                      children: [
                        // Speed chip
                        GestureDetector(
                          onTap: _showSpeedPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.4)),
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
                        ),
                        const SizedBox(width: 8),
                        // Background play toggle (battery saver / audio-only mode)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _batterySaver = !_batterySaver);
                          },
                          child: Icon(
                            _batterySaver
                                ? Icons.headphones_rounded
                                : Icons.headphones_outlined,
                            color: _batterySaver
                                ? AppColors.accentGreen
                                : Colors.white70,
                            size: 22,
                          ),
                        ),
                        const Spacer(),
                        // Aspect ratio toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _aspectRatioIndex =
                                (_aspectRatioIndex + 1) % 3);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    _aspectRatioLabels[_aspectRatioIndex]),
                                backgroundColor: AppColors.surface,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.aspect_ratio_rounded,
                              color: Colors.white70, size: 22),
                        ),
                        const SizedBox(width: 16),
                        // PiP button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (_pipSupported) {
                              PipService.instance.enterPip();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Pop-up not supported'),
                                  backgroundColor: AppColors.surface,
                                ),
                              );
                            }
                          },
                          child: const Icon(
                              Icons.picture_in_picture_alt_rounded,
                              color: Colors.white70,
                              size: 22),
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
      onTap: () {}, // absorb all touches
      child: Center(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isLocked = false);
            _resetHideTimer();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
                child: const Icon(Icons.lock_rounded,
                    color: AppColors.accent, size: 36),
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
    );
  }

  // ── Player wiring ──────────────────────────────────────────────────

  void _attachPlayer(Player player) {
    if (_player == player) return; // already attached
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _player = player;

    _positionSub = player.stream.position.listen((p) {
      if (mounted && !_isSeeking) setState(() => _position = p);
    });
    _durationSub = player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _playingSub = player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    // Unregister from PlaybackCoordinator so it no longer holds a reference
    // to this disposed player instance.
    if (_player != null) {
      PlaybackCoordinator.instance.unregister(_player!);
    }
    // _restoreOrientation() is async but dispose() cannot be async.
    // Schedule it as a fire-and-forget microtask so SystemChrome calls
    // still execute after the widget tree is torn down.
    Future.microtask(_restoreOrientation);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_batterySaver) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _BatterySaverOverlay(
          mediaItem: widget.mediaItem,
          onResume: () => setState(() => _batterySaver = false),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video engine (full screen) with gesture handling
          VideoGestureLayer(
            onSeek: (delta) {
              if (_player == null) return;
              final newPos = _position + delta;
              final clamped = newPos < Duration.zero
                  ? Duration.zero
                  : (newPos > _duration ? _duration : newPos);
              _player!.seek(clamped);
              if (mounted) setState(() => _position = clamped);
            },
            child: MediaKitEngine(
              filePath:      widget.mediaItem.filePath,
              title:         widget.mediaItem.title,
              startPosition: _savedPosition,
              autoPlay:      true,
              fit:           _aspectRatioFits[_aspectRatioIndex],
              onPlayerReady: _attachPlayer,
            ),
          ),

          // 2. Only catch taps to show controls when they are hidden.
          //    When controls ARE visible this layer is absent so taps reach
          //    the controls overlay (layer 3) unobstructed.
          if (!_controlsVisible && !_isLocked)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _resetHideTimer,
                child: const SizedBox.expand(),
              ),
            ),

          // 3. Controls overlay (animated, hidden when locked)
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

          // 4. Lock screen (always visible when locked)
          if (_isLocked) _buildLockOverlay(),
        ],
      ),
    );
  }
}

class _BatterySaverOverlay extends StatelessWidget {
  final MediaItem    mediaItem;
  final VoidCallback onResume;
  const _BatterySaverOverlay({required this.mediaItem, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.battery_saver_rounded,
                color: AppColors.accentGreen, size: 64),
            const SizedBox(height: 16),
            const Text('Battery Saver Active',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 20,
                    fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            const Text(
                'Audio playing in background.\nVideo rendering paused.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13,
                    height: 1.5, fontFamily: 'Inter')),
            const SizedBox(height: 32),
            _AudioWaveAnimation(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Resume Video',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontFamily: 'Inter')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioWaveAnimation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Container(
          width: 4,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleY(
              begin: 0.2,
              end: 1.0,
              duration: Duration(milliseconds: 400 + (i * 80)),
              curve: Curves.easeInOut,
            );
      }),
    );
  }
}

// ── Audio Track Sheet ─────────────────────────────────────────────────────

class _AudioTrackSheet extends StatelessWidget {
  final List<AudioTrack> tracks;
  final AudioTrack activeTrack;
  final void Function(AudioTrack) onSelect;
  const _AudioTrackSheet({required this.tracks, required this.activeTrack, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Audio Track', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Inter')),
          const SizedBox(height: 12),
          ...tracks.map((t) {
            final isActive = t.id == activeTrack.id;
            final label = (t.language?.isNotEmpty == true) ? t.language! : (t.title?.isNotEmpty == true) ? t.title! : 'Track ${tracks.indexOf(t) + 1}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: isActive ? AppColors.accent : AppColors.textSecondary, size: 20),
              title: Text(label, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal, color: isActive ? AppColors.accent : AppColors.textPrimary, fontFamily: 'Inter')),
              onTap: () { Navigator.pop(context); onSelect(t); },
            );
          }),
        ],
      ),
    );
  }
}
