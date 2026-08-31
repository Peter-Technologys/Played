import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Canonical Otya AI identity: only the blue, red and yellow balls.
///
/// The larger folded O belongs to the Otya product/app identity. Otya AI uses
/// these three balls everywhere; they stay still while idle and travel the same
/// curved loop only while Otya is working.
class OtyaAiMark extends StatelessWidget {
  const OtyaAiMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Otya AI',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: const CustomPaint(painter: _OtyaAiPainter()),
        ),
      );
}

/// Backward-compatible thinking widget used by existing Ask Otya surfaces.
/// It now intentionally renders the AI identity rather than the large O mark.
class OtyaThinkingMark extends StatefulWidget {
  const OtyaThinkingMark({
    super.key,
    this.size = 52,
    this.thinking = true,
    this.duration = const Duration(milliseconds: 1650),
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
        label: widget.thinking ? 'Otya AI is thinking' : 'Otya AI',
        image: true,
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              painter: _OtyaAiPainter(
                progress: widget.thinking ? _controller.value : null,
              ),
            ),
          ),
        ),
      );
}

class _OtyaAiPainter extends CustomPainter {
  const _OtyaAiPainter({this.progress});

  final double? progress;

  static const _blue = Color(0xFF2979FF);
  static const _red = Color(0xFFFF3B30);
  static const _yellow = Color(0xFFFFD60A);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .14;
    final routeX = size.width * .31;
    final routeY = size.height * .22;

    if (progress == null) {
      _ball(canvas, Offset(size.width * .25, size.height * .58), radius, _blue);
      _ball(canvas, Offset(size.width * .50, size.height * .36), radius, _red);
      _ball(canvas, Offset(size.width * .75, size.height * .58), radius, _yellow);
      return;
    }

    final base = progress! * math.pi * 2;
    const colors = [_blue, _red, _yellow];
    for (var i = 0; i < colors.length; i++) {
      final angle = base - i * .34;
      final point = Offset(
        center.dx + math.cos(angle) * routeX,
        center.dy + math.sin(angle) * routeY,
      );
      _ball(canvas, point, radius, colors[i]);
    }
  }

  void _ball(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center.translate(radius * .12, radius * .22),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: .18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .28),
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.45),
          radius: .95,
          colors: [
            Colors.white.withValues(alpha: .88),
            color,
            Color.lerp(color, Colors.black, .22)!,
          ],
          stops: const [0, .28, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _OtyaAiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
