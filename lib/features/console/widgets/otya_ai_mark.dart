import 'dart:math' as math;

import 'package:flutter/material.dart';

/// OTYA AI identity mark.
///
/// The full OTYA brand logo remains unchanged. AI is represented only by
/// these three colored balls. They stay still while idle and move on curved
/// paths while AI is working.
class OtyaAiMark extends StatefulWidget {
  const OtyaAiMark({
    super.key,
    this.size = 28,
    this.isActive = false,
    this.duration = const Duration(milliseconds: 1800),
  });

  final double size;
  final bool isActive;
  final Duration duration;

  @override
  State<OtyaAiMark> createState() => _OtyaAiMarkState();
}

class _OtyaAiMarkState extends State<OtyaAiMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant OtyaAiMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.isActive != widget.isActive) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.isActive) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.animateBack(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _OtyaAiPainter(progress: _controller.value),
        ),
      ),
    );
  }
}

class _OtyaAiPainter extends CustomPainter {
  const _OtyaAiPainter({required this.progress});

  final double progress;

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .32;
    final ballRadius = size.shortestSide * .105;

    // Stable triangular idle arrangement; animation moves the balls around an
    // invisible center, never drawing the full OTYA logo behind them.
    final phase = progress * math.pi * 2;
    final angles = <double>[
      -math.pi * .72,
      -math.pi * .28,
      math.pi * .5,
    ];
    final colors = <Color>[_blue, _red, _yellow];

    for (var i = 0; i < 3; i++) {
      final wobble = math.sin((phase * 2) + i) * radius * .08;
      final a = angles[i] + phase;
      final point = Offset(
        center.dx + math.cos(a) * (radius + wobble),
        center.dy + math.sin(a) * (radius - wobble),
      );
      canvas.drawCircle(point, ballRadius, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _OtyaAiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
