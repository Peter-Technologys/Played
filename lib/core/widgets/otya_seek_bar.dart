// OtyaSeekBar — custom painted seek bar for OTYA Player.
// Extracted and rebranded from Updates-mavplayer/lib/style/slider.dart
// (originally FSlider by Befovy, MIT licence).
// Changes: renamed, removed `part of fplayer`, OTYA accent colours,
// larger thumb for better touch target, OtyaSeekBarColors.branded() factory.

import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class OtyaSeekBarColors {
  final Color playedColor;
  final Color bufferedColor;
  final Color cursorColor;
  final Color baselineColor;

  const OtyaSeekBarColors({
    this.playedColor   = const Color(0xFF00D4FF),
    this.bufferedColor = const Color(0x5500D4FF),
    this.cursorColor   = const Color(0xFF00D4FF),
    this.baselineColor = const Color(0x44FFFFFF),
  });

  factory OtyaSeekBarColors.branded() => OtyaSeekBarColors(
    playedColor:   AppColors.accent,
    bufferedColor: AppColors.accent.withValues(alpha: 0.33),
    cursorColor:   AppColors.accent,
    baselineColor: Colors.white.withValues(alpha: 0.25),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtyaSeekBarColors && hashCode == other.hashCode;

  @override
  int get hashCode =>
      Object.hash(playedColor, bufferedColor, cursorColor, baselineColor);
}

class OtyaSeekBar extends StatefulWidget {
  final double value;
  final double bufferValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final OtyaSeekBarColors colors;

  const OtyaSeekBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.bufferValue = 0.0,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.colors = const OtyaSeekBarColors(),
  })  : assert(min <= max),
        assert(value >= min && value <= max);

  @override
  State<OtyaSeekBar> createState() => _OtyaSeekBarState();
}

class _OtyaSeekBarState extends State<OtyaSeekBar> {
  bool   _dragging  = false;
  double _dragValue = 0.0;
  static const double _margin = 2.0;

  @override
  Widget build(BuildContext context) {
    final v  = (widget.value       - widget.min) / (widget.max - widget.min);
    final cv = (widget.bufferValue - widget.min) / (widget.max - widget.min);
    return GestureDetector(
      onHorizontalDragStart: (d) {
        setState(() => _dragging = true);
        _dragValue = widget.value;
        widget.onChangeStart?.call(_dragValue);
      },
      onHorizontalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox;
        _dragValue = ((d.localPosition.dx - _margin) /
                (box.size.width - 2 * _margin))
            .clamp(0.0, 1.0);
        _dragValue = _dragValue * (widget.max - widget.min) + widget.min;
        widget.onChanged(_dragValue);
      },
      onHorizontalDragEnd: (d) {
        setState(() => _dragging = false);
        widget.onChangeEnd?.call(_dragValue);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: _margin),
        height: double.infinity,
        width:  double.infinity,
        color:  Colors.transparent,
        child: CustomPaint(
          painter: _OtyaSeekBarPainter(v, cv, _dragging, colors: widget.colors),
        ),
      ),
    );
  }
}

class _OtyaSeekBarPainter extends CustomPainter {
  final double v;
  final double cv;
  final bool   dragging;
  final OtyaSeekBarColors colors;
  final Paint  _pt = Paint();

  _OtyaSeekBarPainter(this.v, this.cv, this.dragging,
      {this.colors = const OtyaSeekBarColors()});

  @override
  void paint(Canvas canvas, Size size) {
    final lineH  = min(size.height / 2, 2.0);
    final radius = Radius.circular(min(size.height / 2, 4.0));
    final mid    = size.height / 2;

    // baseline
    _pt.color = colors.baselineColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromPoints(Offset(0, mid - lineH), Offset(size.width, mid + lineH)),
          radius),
      _pt,
    );

    final played   = v  * size.width;
    final buffered = cv * size.width;

    // buffered
    if (buffered > played && buffered > 0) {
      _pt.color = colors.bufferedColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromPoints(Offset(played, mid - lineH), Offset(buffered, mid + lineH)),
            radius),
        _pt,
      );
    }

    // played
    _pt.color = colors.playedColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromPoints(Offset(0, mid - lineH), Offset(played, mid + lineH)),
          radius),
      _pt,
    );

    // thumb glow
    _pt.color = colors.cursorColor.withAlpha(
        max(0, colors.cursorColor.alpha - 80));
    canvas.drawCircle(
        Offset(played, mid), min(mid, dragging ? 12.0 : 6.0), _pt);

    // thumb
    _pt.color = colors.cursorColor;
    canvas.drawCircle(
        Offset(played, mid), min(mid, dragging ? 7.0 : 4.0), _pt);
  }

  @override
  bool shouldRepaint(_OtyaSeekBarPainter old) => hashCode != old.hashCode;

  @override
  int get hashCode => Object.hash(v, cv, dragging, colors);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _OtyaSeekBarPainter && hashCode == other.hashCode;
}
