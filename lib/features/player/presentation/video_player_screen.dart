import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../features/settings/settings_provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/pip_service.dart';
import 'widgets/gesture_detector_layer.dart';
import 'widgets/battery_saver_toggle.dart';
import 'widgets/player_controls.dart';

// ── Providers ──────────────────────────────────────────────

final batterySaverProvider = StateProvider<bool>((_) => false);
final controlsVisibleProvider = StateProvider<bool>((_) => true);
final brightnessProvider = StateProvider<double>((_) => 0.5);
final volumeProvider = StateProvider<double>((_) => 0.8);

// ── Screen ────────────────────────────────────────────────────

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  const VideoPlayerScreen({super.key, required this.mediaItem});

  @override
  ConsumerState<VideoPlayerScreen> createState() =>
      _VideoPlayerScreenState();
}

class _VideoPlayerScreenState
    extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late VlcPlayerController _vlcController;
  Timer? _controlsTimer;
  bool _isInitialized = false;
  // Debounce timer for seek-position saves to avoid write storms
  Timer? _savePositionTimer;

  // PiP state
  bool _pipSupported = false;
  bool _pipAutoEnabled = false;
  bool _isInPip = false;
  bool _screenLocked = false;
  bool _isSpeedBoosting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockToLandscape();
    _initPlayer();
    _initPip();
  }

  Future<void> _initPip() async {
    _pipSupported = await PipService.instance.isPipSupported();
    final settings = ref.read(settingsProvider);
    _pipAutoEnabled = settings.autoPip;
  }

  Future<void> _initPlayer() async {
    final savedPosition =
        PlayedDatabase.instance.getSeekPosition(widget.mediaItem.id);

    final subtitlePath = _findSubtitle(widget.mediaItem.filePath);

    _vlcController = VlcPlayerController.file(
      File(widget.mediaItem.filePath),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
        ]),
        video: VlcVideoOptions([
          VlcVideoOptions.dropLateFrames(true),
          VlcVideoOptions.skipFrames(true),
        ]),
        extras: subtitlePath != null
            ? ['--sub-file=$subtitlePath']
            : [],
      ),
    );

    _vlcController.addListener(_onPlayerStateChanged);

    // Set initialized immediately so the VLC surface widget is added to the
    // tree and VLC can attach to it. Waiting caused a blank black screen.
    if (mounted) setState(() => _isInitialized = true);

    // Seek to saved position after VLC has had time to buffer
    if (savedPosition != null && savedPosition.inSeconds > 0) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _vlcController.seekTo(savedPosition);
    }

    _startControlsTimer();
  }

  /// Looks for a .srt or .ass subtitle file with the same base name
  /// as the video in the same directory. Returns the path if found.
  String? _findSubtitle(String videoPath) {
    try {
      final base = videoPath.replaceAll(RegExp(r'\.[^.]+$'), '');
      for (final ext in ['.srt', '.ass', '.ssa', '.vtt']) {
        final f = File('$base$ext');
        if (f.existsSync()) return f.path;
      }
    } catch (_) {}
    return null;
  }

  void _onPlayerStateChanged() {
    // Debounce position saves to every 5 seconds of real time,
    // not every time the VLC listener fires (which is ~every frame).
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      final pos = _vlcController.value.position;
      if (pos.inSeconds > 0) {
        PlayedDatabase.instance
            .saveSeekPosition(widget.mediaItem.id, pos)
            .ignore();
      }
    });
  }

  void _saveCurrentPosition() {
    try {
      final pos = _vlcController.value.position;
      if (pos.inSeconds > 0) {
        PlayedDatabase.instance
            .saveSeekPosition(widget.mediaItem.id, pos)
            .ignore();
      }
    } catch (_) {}
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    ref.read(controlsVisibleProvider.notifier).state = true;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        ref.read(controlsVisibleProvider.notifier).state = false;
      }
    });
  }

  void _toggleControls() {
    if (_screenLocked) return; // locked screen ignores taps
    final visible = ref.read(controlsVisibleProvider);
    if (visible) {
      _controlsTimer?.cancel();
      ref.read(controlsVisibleProvider.notifier).state = false;
    } else {
      _startControlsTimer();
    }
  }

  // ── PiP ────────────────────────────────────────────────────

  /// Called when the user manually taps the PiP button.
  /// Enters PiP and remembers the preference so future app-background
  /// events also trigger PiP automatically (like PlayIt).
  Future<void> _enterPipManual() async {
    if (!_pipSupported) return;
    // Remember that the user has opted in
    if (!_pipAutoEnabled) {
      ref.read(settingsProvider.notifier).setAutoPip(true);
      _pipAutoEnabled = true;
    }
    await PipService.instance.enterPip();
    if (mounted) setState(() => _isInPip = true);
  }

  /// Called when the user taps the PiP button for the first time —
  /// shows a one-time explanation before entering PiP.
  Future<void> _onPipButtonTapped() async {
    if (!_pipSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Picture-in-Picture is not supported on this device.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    if (!_pipAutoEnabled) {
      // First time — explain what PiP does
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Picture in Picture',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'The video will float over other apps.\n\n'
            'After using it once, PLAYED will automatically enter PiP '
            'whenever you leave the app while a video is playing — just like PlayIt.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enter PiP',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _enterPipManual();
  }

  // ── Screen lock ─────────────────────────────────────────────

  void _toggleScreenLock() {
    setState(() => _screenLocked = !_screenLocked);
    if (_screenLocked) {
      _controlsTimer?.cancel();
      ref.read(controlsVisibleProvider.notifier).state = false;
    } else {
      _startControlsTimer();
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Save position
      _saveCurrentPosition();
      // Auto-PiP: only if user has opted in by using it manually before
      if (_pipAutoEnabled && _pipSupported && !_isInPip) {
        PipService.instance.enterPip();
        if (mounted) setState(() => _isInPip = true);
      }
    }
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _isInPip = false);
    }
  }

  Future<void> _lockToLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreOrientation() async {
    await SystemChrome.setPreferredOrientations(
        DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _savePositionTimer?.cancel();
    _vlcController.removeListener(_onPlayerStateChanged);
    // Save position before disposing so resume works next time
    _saveCurrentPosition();
    _vlcController.dispose();
    _restoreOrientation();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batterySaver = ref.watch(batterySaverProvider);
    final controlsVisible = ref.watch(controlsVisibleProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video Surface ────────────────────────────────────
          if (_isInitialized && !batterySaver)
            Center(
              child: VlcPlayer(
                controller: _vlcController,
                aspectRatio: 16 / 9,
                placeholder: const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accent),
                ),
              ),
            ),

          // ── Battery Saver Overlay ───────────────────────────
          if (batterySaver)
            _BatterySaverOverlay(mediaItem: widget.mediaItem)
                .animate()
                .fadeIn(duration: 400.ms),

          // ── Screen Lock Overlay ─────────────────────────────
          if (_screenLocked)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleScreenLock,
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            color: AppColors.accent, size: 22),
                        SizedBox(height: 4),
                        Text('Tap to\nunlock',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Long-press 2× speed boost (like PlayIt) ──────────────────
          if (!_screenLocked)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressStart: (_) {
                  _vlcController.setPlaybackSpeed(2.0);
                  if (mounted) setState(() => _isSpeedBoosting = true);
                },
                onLongPressEnd: (_) {
                  _vlcController.setPlaybackSpeed(1.0);
                  if (mounted) setState(() => _isSpeedBoosting = false);
                },
              ),
            ),

          // Speed boost badge
          if (_isSpeedBoosting)
            Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fast_forward_rounded,
                          color: AppColors.accent, size: 18),
                      SizedBox(width: 6),
                      Text('2× Speed',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Gesture Layer ──────────────────────────────────
          if (!_screenLocked)
            GestureDetectorLayer(
              onTap: _toggleControls,
              onBrightnessChange: (delta) {
                final current = ref.read(brightnessProvider);
                ref.read(brightnessProvider.notifier).state =
                    (current + delta).clamp(0.0, 1.0);
              },
              onVolumeChange: (delta) {
                final current = ref.read(volumeProvider);
                final newVol = (current + delta).clamp(0.0, 1.0);
                ref.read(volumeProvider.notifier).state = newVol;
                _vlcController.setVolume((newVol * 100).toInt());
              },
              onSeek: (delta) {
                final current = _vlcController.value.position;
                _vlcController.seekTo(current + delta);
                _startControlsTimer();
              },
            ),

          // ── Controls Overlay ───────────────────────────────
          if (!_screenLocked)
            AnimatedOpacity(
              opacity: controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: PlayerControls(
                  controller: _vlcController,
                  mediaItem: widget.mediaItem,
                  onBack: () => Navigator.of(context).pop(),
                  onPip: _onPipButtonTapped,
                  onLockScreen: _toggleScreenLock,
                ),
              ),
            ),

          // ── Battery Saver Toggle ───────────────────────────
          if (!_screenLocked)
            Positioned(
              top: 16,
              right: 16,
              child: BatterySaverToggle(
                isActive: batterySaver,
                onToggle: (val) {
                  ref.read(batterySaverProvider.notifier).state = val;
                  if (val) {
                    _vlcController.setVideoTrack(-1);
                  } else {
                    _vlcController.setVideoTrack(0);
                  }
                },
              ),
            ),

          // ── Brightness / Volume Indicators — hidden when controls are hidden
          AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !controlsVisible,
              child: _SwipeIndicators(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Battery Saver Overlay ──────────────────────────────────

class _BatterySaverOverlay extends StatelessWidget {
  final MediaItem mediaItem;
  const _BatterySaverOverlay({required this.mediaItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.battery_saver_rounded,
                color: AppColors.accent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Battery Saver Active',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Audio playing in background.\nVideo rendering paused.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _AudioWaveAnimation(),
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
            borderRadius: BorderRadius.circular(2),
          ),
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

// ── Swipe Indicators ─────────────────────────────────────────

class _SwipeIndicators extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessProvider);
    final volume = ref.watch(volumeProvider);

    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: _VerticalIndicator(
              icon: Icons.brightness_6_rounded,
              value: brightness,
              color: Colors.amber,
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: _VerticalIndicator(
              icon: Icons.volume_up_rounded,
              value: volume,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerticalIndicator extends StatelessWidget {
  final IconData icon;
  final double value;
  final Color color;

  const _VerticalIndicator({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          width: 4,
          child: RotatedBox(
            quarterTurns: -1,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(value * 100).toInt()}%',
          style: const TextStyle(
              color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
