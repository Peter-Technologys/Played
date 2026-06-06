import 'package:flutter/material.dart';

/// Handles all swipe gesture logic for the full-screen player.
/// - Vertical swipe LEFT half  → Brightness
/// - Vertical swipe RIGHT half → Volume
/// - Horizontal swipe          → Seek ±10s
class GestureDetectorLayer extends StatefulWidget {
  final VoidCallback onTap;
  final ValueChanged<double> onBrightnessChange;
  final ValueChanged<double> onVolumeChange;
  final ValueChanged<Duration> onSeek;

  const GestureDetectorLayer({
    super.key,
    required this.onTap,
    required this.onBrightnessChange,
    required this.onVolumeChange,
    required this.onSeek,
  });

  @override
  State<GestureDetectorLayer> createState() =>
      _GestureDetectorLayerState();
}

class _GestureDetectorLayerState extends State<GestureDetectorLayer> {
  static const double _sensitivity = 0.003;
  static const Duration _seekStep = Duration(seconds: 10);

  Offset? _dragStart;
  bool? _isHorizontalDrag;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onDoubleTapDown: (details) {
        if (details.localPosition.dx < screenWidth / 2) {
          widget.onSeek(-_seekStep);
        } else {
          widget.onSeek(_seekStep);
        }
      },
      onVerticalDragStart: (details) {
        _dragStart = details.localPosition;
        _isHorizontalDrag = false;
      },
      onVerticalDragUpdate: (details) {
        if (_isHorizontalDrag == true) return;
        final delta = -details.delta.dy * _sensitivity;
        final isLeftSide =
            (_dragStart?.dx ?? 0) < screenWidth / 2;
        if (isLeftSide) {
          widget.onBrightnessChange(delta);
        } else {
          widget.onVolumeChange(delta);
        }
      },
      onHorizontalDragStart: (_) => _isHorizontalDrag = true,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        if (velocity < 0) {
          widget.onSeek(_seekStep);
        } else {
          widget.onSeek(-_seekStep);
        }
        _isHorizontalDrag = null;
      },
      child: const SizedBox.expand(),
    );
  }
}
