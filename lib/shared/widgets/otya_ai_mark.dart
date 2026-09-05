import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'otya_logo_v2.dart';

/// Next is part of the Otya product identity, not a second brand.
///
/// The idle state uses the exact same approved Otya mark as the rest of the
/// app. Thinking adds a lightweight cyan/blue activity arc around the static
/// mark so the identity remains recognisable while work is in progress.
class OtyaAiMark extends StatelessWidget {
  const OtyaAiMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Next',
        image: true,
        child: OtyaMark(size: size),
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
    _syncMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = widget.thinking && !reduceMotion;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markSize = widget.size * .78;
    return Semantics(
      label: widget.thinking ? 'Next is thinking' : 'Next',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            OtyaMark(size: markSize),
            if (widget.thinking)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => CustomPaint(
                      painter: _ThinkingArcPainter(progress: _controller.value),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingArcPainter extends CustomPainter {
  const _ThinkingArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(2.0, size.shortestSide * .055);
    final inset = stroke * .8;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final start = progress * math.pi * 2 - math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.brandBlue.withValues(alpha: .14);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          AppColors.brandCyan,
          AppColors.brandBlue,
          AppColors.brandDeepBlue,
          AppColors.brandCyan,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, start, math.pi * .72, false, active);
  }

  @override
  bool shouldRepaint(covariant _ThinkingArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
