import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:media_kit/media_kit.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_kit_engine.dart';
import '../../../core/services/pip_service.dart';
import '../../../features/player/presentation/widgets/video_gesture_layer.dart';
import '../../../features/settings/settings_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _savedPosition =
        PlayedDatabase.instance.getSeekPosition(widget.mediaItem.id) ??
        Duration.zero;
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

  // ── Duration formatter ─────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Speed picker ───────────────────────────────────────────────────

  void _showSpeedPicker() {
    HapticFeedback.selectionClick();
    const speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const Text('Playback Speed',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: speeds.map((s) {
                final isActive = _playbackSpeed == s;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _playbackSpeed = s);
                    _player?.setRate(s);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentViolet])
                          : null,
                      color: isActive ? null : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? Colors.transparent
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${s}x',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.black : AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
                    // CC toggle
                    IconButton(
                      icon: Icon(
                        Icons.closed_caption_rounded,
                        color: _ccEnabled ? AppColors.accent : Colors.white70,
                        size: 22,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _ccEnabled = !_ccEnabled);
                      },
                      tooltip: 'Subtitles',
                    ),
                    // Background audio
                    IconButton(
                      icon: const Icon(Icons.headphones_rounded,
                          color: Colors.white70, size: 22),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                      tooltip: 'Background audio',
                    ),
                    // Queue
                    IconButton(
                      icon: const Icon(Icons.queue_music_rounded,
                          color: Colors.white70, size: 22),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Queue not available for video'),
                            backgroundColor: AppColors.surface,
                          ),
                        );
                      },
                      tooltip: 'Queue',
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
              // Trim/Clip
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Video trimmer coming soon'),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                },
                child: const Icon(Icons.content_cut_rounded,
                    color: Colors.white70, size: 24),
              ),
              const SizedBox(height: 16),
              // Orientation lock
              GestureDetector(
                onTap: _toggleOrientation,
                child: const Icon(Icons.screen_rotation_rounded,
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
                          _formatDuration(_position),
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
                          _formatDuration(_duration),
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
                        const SizedBox(width: 24),
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
                        const SizedBox(width: 24),
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
                                      'PiP not supported on this device'),
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
    _restoreOrientation();
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
