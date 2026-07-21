import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';

/// Gesture layer for video player.
/// Left-half vertical swipe  → Brightness
/// Right-half vertical swipe → Volume
/// Horizontal swipe / double-tap → Seek ±10 s (via [onSeek] callback)
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

  final _brightnessNotifier = ValueNotifier<double>(0.5);
  final _volumeNotifier     = ValueNotifier<double>(0.5);
  final _showBrightness     = ValueNotifier<bool>(false);
  final _showVolume         = ValueNotifier<bool>(false);

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _readInitialValues();
  }

  Future<void> _readInitialValues() async {
    try {
      final b = await _brightnessChannel.invokeMethod<double>('getBrightness');
      if (b != null) _brightnessNotifier.value = b.clamp(0.0, 1.0);
    } catch (_) {}
    try {
      final v = await _volumeChannel.invokeMethod<double>('getVolume');
      if (v != null) _volumeNotifier.value = v.clamp(0.0, 1.0);
    } catch (_) {}
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      _showBrightness.value = false;
      _showVolume.value     = false;
    });
  }

  Future<void> _applyBrightness(double delta) async {
    final next = (_brightnessNotifier.value + delta).clamp(0.0, 1.0);
    _brightnessNotifier.value = next;
    _showBrightness.value     = true;
    try {
      await _brightnessChannel.invokeMethod('setBrightness', {'value': next});
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _applyVolume(double delta) async {
    final next = (_volumeNotifier.value + delta).clamp(0.0, 1.0);
    _volumeNotifier.value = next;
    _showVolume.value     = true;
    try {
      await _volumeChannel.invokeMethod('setVolume', {'value': next});
    } catch (_) {}
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _brightnessNotifier.dispose();
    _volumeNotifier.dispose();
    _showBrightness.dispose();
    _showVolume.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: (d) {
              if (widget.onSeek == null) return;
              if (d.localPosition.dx < screenWidth / 2) {
                widget.onSeek!(const Duration(seconds: -10));
              } else {
                widget.onSeek!(const Duration(seconds: 10));
              }
            },
            onHorizontalDragEnd: (d) {
              if (widget.onSeek == null) return;
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 200) return;
              widget.onSeek!(Duration(seconds: v < 0 ? 10 : -10));
            },
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (d) =>
                        _applyBrightness(-d.delta.dy / 180),
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (d) =>
                        _applyVolume(-d.delta.dy / 180),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _showBrightness,
          builder: (_, show, __) => show
              ? Positioned(
                  left: 24, top: 0, bottom: 0,
                  child: Center(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _brightnessNotifier,
                      builder: (_, v, __) => _GestureOverlay(
                        icon: Icons.brightness_6_rounded,
                        value: v,
                        label: '${(v * 100).round()}%',
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
                  right: 24, top: 0, bottom: 0,
                  child: Center(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _volumeNotifier,
                      builder: (_, v, __) => _GestureOverlay(
                        icon: Icons.volume_up_rounded,
                        value: v,
                        label: '${(v * 100).round()}%',
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

class _GestureOverlay extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  const _GestureOverlay({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            width: 6,
            child: RotatedBox(
              quarterTurns: -1,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
