import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/media_item.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockToLandscape();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final savedPosition =
        PlayedDatabase.instance.getSeekPosition(widget.mediaItem.id);

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
      ),
    );

    _vlcController.addListener(_onPlayerStateChanged);

    if (savedPosition != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      _vlcController.seekTo(savedPosition);
    }

    setState(() => _isInitialized = true);
    _startControlsTimer();
  }

  void _onPlayerStateChanged() {
    final pos = _vlcController.value.position;
    if (pos.inSeconds % 5 == 0 && pos.inSeconds > 0) {
      PlayedDatabase.instance
          .saveSeekPosition(widget.mediaItem.id, pos);
    }
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
    final visible = ref.read(controlsVisibleProvider);
    if (visible) {
      _controlsTimer?.cancel();
      ref.read(controlsVisibleProvider.notifier).state = false;
    } else {
      _startControlsTimer();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      PlayedDatabase.instance.saveSeekPosition(
        widget.mediaItem.id,
        _vlcController.value.position,
      );
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _vlcController.removeListener(_onPlayerStateChanged);
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

          // ── Gesture Layer ──────────────────────────────────
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
          AnimatedOpacity(
            opacity: controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !controlsVisible,
              child: PlayerControls(
                controller: _vlcController,
                mediaItem: widget.mediaItem,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // ── Battery Saver Toggle ───────────────────────────
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

          // ── Brightness / Volume Indicators ──────────────────
          _SwipeIndicators(),
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
