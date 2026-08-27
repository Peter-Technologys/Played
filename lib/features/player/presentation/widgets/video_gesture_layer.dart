import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/playback_coordinator.dart';

/// Gesture layer for the video player.
///
/// Left-half vertical swipe  → brightness
/// Right-half vertical swipe → volume
/// Double-tap left/right     → seek ±10 seconds
/// Horizontal fling          → seek ±10 seconds
/// Long press                → real 2× playback while held
class VideoGestureLayer extends StatefulWidget {
  final Widget child;
  final void Function(Duration delta)? onSeek;

  const VideoGestureLayer({
    super.key,
    required this.child,
    this.onSeek,
  });

  @override
  State<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

class _VideoGestureLayerState extends State<VideoGestureLayer> {
  static const _brightnessChannel =
      MethodChannel('com.otyaplayer.app/brightness');
  static const _volumeChannel = MethodChannel('com.otyaplayer.app/volume');

  final _brightness = ValueNotifier<double>(0.5);
  final _volume = ValueNotifier<double>(0.5);
  final _showBrightness = ValueNotifier<bool>(false);
  final _showVolume = ValueNotifier<bool>(false);

  Timer? _hudTimer;
  Timer? _seekTimer;
  bool _showSeekRipple = false;
  bool _seekForward = true;
  bool _speedBoosted = false;

  @override
  void initState() {
    super.initState();
    _readInitialValues();
  }

  Future<void> _readInitialValues() async {
    try {
      final b = await _brightnessChannel.invokeMethod<double>('getBrightness');
      if (b != null) _brightness.value = b < 0 ? 0.5 : b.clamp(0.0, 1.0);
    } catch (_) {}
    try {
      final v = await _volumeChannel.invokeMethod<double>('getVolume');
      if (v != null) _volume.value = v.clamp(0.0, 1.0);
    } catch (_) {}
  }

  void _scheduleHudHide() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1600), () {
      _showBrightness.value = false;
      _showVolume.value = false;
    });
  }

  Future<void> _applyBrightness(double delta) async {
    final next = (_brightness.value + delta).clamp(0.0, 1.0);
    _brightness.value = next;
    _showBrightness.value = true;
    _showVolume.value = false;
    try {
      await _brightnessChannel.invokeMethod('setBrightness', {'value': next});
    } catch (_) {}
    _scheduleHudHide();
  }

  Future<void> _applyVolume(double delta) async {
    final next = (_volume.value + delta).clamp(0.0, 1.0);
    _volume.value = next;
    _showVolume.value = true;
    _showBrightness.value = false;
    try {
      await _volumeChannel.invokeMethod('setVolume', {'value': next});
    } catch (_) {}
    _scheduleHudHide();
  }

  void _seek(bool forward) {
    if (widget.onSeek == null) return;
    widget.onSeek!(Duration(seconds: forward ? 10 : -10));
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _seekForward = forward;
      _showSeekRipple = true;
    });
    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showSeekRipple = false);
    });
  }

  Future<void> _beginSpeedBoost() async {
    final ok = await PlaybackCoordinator.instance.beginSpeedBoost(rate: 2.0);
    if (!ok || !mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _speedBoosted = true);
  }

  Future<void> _endSpeedBoost() async {
    if (!_speedBoosted) return;
    await PlaybackCoordinator.instance.endSpeedBoost();
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _speedBoosted = false);
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _seekTimer?.cancel();
    if (_speedBoosted) {
      PlaybackCoordinator.instance.endSpeedBoost();
    }
    _brightness.dispose();
    _volume.dispose();
    _showBrightness.dispose();
    _showVolume.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: (details) =>
                _seek(details.localPosition.dx >= screenWidth / 2),
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() >= 300) _seek(velocity > 0);
            },
            onLongPressStart: (_) => _beginSpeedBoost(),
            onLongPressEnd: (_) => _endSpeedBoost(),
            onLongPressCancel: _endSpeedBoost,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) =>
                        _applyBrightness(-details.delta.dy / 220),
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) =>
                        _applyVolume(-details.delta.dy / 220),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_speedBoosted)
          const Positioned(
            top: 18,
            left: 0,
            right: 0,
            child: Center(child: _StatusPill(icon: Icons.fast_forward_rounded, label: '2× Speed')),
          ),
        if (_showSeekRipple)
          Positioned.fill(
            child: IgnorePointer(
              child: _SeekRipple(forward: _seekForward),
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: _showBrightness,
          builder: (_, show, __) => show
              ? Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _brightness,
                      builder: (_, value, __) => _GlassHud(
                        icon: Icons.brightness_6_rounded,
                        value: value,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _showVolume,
          builder: (_, show, __) => show
              ? Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _volume,
                      builder: (_, value, __) => _GlassHud(
                        icon: value == 0
                            ? Icons.volume_off_rounded
                            : value < 0.5
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                        value: value,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassHud extends StatelessWidget {
  final IconData icon;
  final double value;

  const _GlassHud({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accent, size: 21),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                width: 7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(
                    children: [
                      Container(color: Colors.white.withValues(alpha: 0.12)),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: value.clamp(0.0, 1.0),
                          child: Container(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekRipple extends StatelessWidget {
  final bool forward;

  const _SeekRipple({required this.forward});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 38),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.40),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                forward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 2),
              Text(
                forward ? '+10s' : '-10s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
