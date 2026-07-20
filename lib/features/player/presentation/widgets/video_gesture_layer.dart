import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';

/// Gesture layer for video player: swipe left/right half for brightness/volume.
class VideoGestureLayer extends StatefulWidget {
  final Widget child;
  const VideoGestureLayer({super.key, required this.child});

  @override
  State<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

class _VideoGestureLayerState extends State<VideoGestureLayer> {
  static const _brightnessChannel =
      MethodChannel('com.otyaplayer.app/brightness');
  static const _volumeChannel =
      MethodChannel('com.otyaplayer.app/volume');

  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightness = false;
  bool _showVolume = false;
  Timer? _hideTimer;
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() { _showBrightness = false; _showVolume = false; });
    });
  }

  Future<void> _setBrightness(double value) async {
    _brightness = value.clamp(0.0, 1.0);
    try {
      await _brightnessChannel.invokeMethod('setBrightness', {'value': _brightness});
    } catch (_) {}
  }

  Future<void> _setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      await _volumeChannel.invokeMethod('setVolume', {'value': _volume});
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Left half = brightness, right half = volume
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: (d) {
                    final delta = -d.delta.dy / 200;
                    setState(() {
                      _brightness = (_brightness + delta).clamp(0.0, 1.0);
                      _showBrightness = true;
                    });
                    _setBrightness(_brightness);
                    _scheduleHide();
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: (d) {
                    final delta = -d.delta.dy / 200;
                    setState(() {
                      _volume = (_volume + delta).clamp(0.0, 1.0);
                      _showVolume = true;
                    });
                    _setVolume(_volume);
                    _scheduleHide();
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        // Brightness overlay
        if (_showBrightness)
          Positioned(
            left: 24, top: 0, bottom: 0,
            child: Center(
              child: _GestureOverlay(
                icon: Icons.brightness_6_rounded,
                value: _brightness,
                label: '${(_brightness * 100).round()}%',
              ),
            ),
          ),
        // Volume overlay
        if (_showVolume)
          Positioned(
            right: 24, top: 0, bottom: 0,
            child: Center(
              child: _GestureOverlay(
                icon: Icons.volume_up_rounded,
                value: _volume,
                label: '${(_volume * 100).round()}%',
              ),
            ),
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
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
