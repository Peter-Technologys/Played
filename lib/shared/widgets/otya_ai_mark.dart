import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Canonical Next identity: three equal balls in an equilateral triangle.
///
/// Idle: blue upper-left, red upper-right, yellow lower-center.
/// Thinking: the whole triangle rotates as one formation, so the three balls
/// stay equally spaced instead of chasing each other in a line.
class OtyaAiMark extends StatelessWidget {
  const OtyaAiMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Next',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: const CustomPaint(painter: _NextPainter()),
        ),
      );
}

class OtyaThinkingMark extends StatefulWidget {
  const OtyaThinkingMark({
    super.key,
    this.size = 52,
    this.thinking = true,
    this.duration = const Duration(milliseconds: 1500),
  });

  final double size;
  final bool thinking;
  final Duration duration;

  @override
  State<OtyaThinkingMark> createState() => _OtyaThinkingMarkState();
}

class _OtyaThinkingMarkState extends State<OtyaThinkingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.thinking) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant OtyaThinkingMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) _controller.duration = widget.duration;
    if (widget.thinking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.thinking && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (widget.thinking && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.thinking ? 'Next is thinking' : 'Next',
        image: true,
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              painter: _NextPainter(
                progress: widget.thinking ? _controller.value : null,
              ),
            ),
          ),
        ),
      );
}

class _NextPainter extends CustomPainter {
  const _NextPainter({this.progress});

  final double? progress;

  static const _blue = Color(0xFF2979FF);
  static const _red = Color(0xFFFF3B30);
  static const _yellow = Color(0xFFFFD60A);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ballRadius = size.shortestSide * .115;
    final orbit = size.shortestSide * .255;
    final rotation = progress == null ? 0.0 : progress! * math.pi * 2;

    // Exact 120-degree spacing: an equilateral triangle at every frame.
    const baseAngles = <double>[
      -5 * math.pi / 6,
      -math.pi / 6,
      math.pi / 2,
    ];
    const colors = [_blue, _red, _yellow];

    for (var i = 0; i < 3; i++) {
      final angle = baseAngles[i] + rotation;
      final point = Offset(
        center.dx + math.cos(angle) * orbit,
        center.dy + math.sin(angle) * orbit,
      );
      _ball(canvas, point, ballRadius, colors[i]);
    }
  }

  void _ball(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center.translate(0, radius * .20),
      radius * 1.04,
      Paint()
        ..color = Colors.black.withValues(alpha: .16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .34),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center.translate(-radius * .28, -radius * .30),
      radius * .22,
      Paint()..color = Colors.white.withValues(alpha: .34),
    );
  }

  @override
  bool shouldRepaint(covariant _NextPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
