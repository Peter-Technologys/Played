import 'dart:math' as math;
import 'package:flutter/material.dart';

/// GlowingNeonProgressRing — circular download progress indicator.
///
/// Performance notes:
///   • Uses CustomPainter with repaint boundary so only this widget
///     repaints when [progress] changes — the rest of the screen is
///     unaffected during heavy file streaming.
///   • The SweepGradient shader is created inside the painter and cached
///     by the framework between frames when [progress] has not changed.
///   • shouldRepaint() returns false when progress is identical, preventing
///     unnecessary rasterisation passes.
class GlowingNeonProgressRing extends StatelessWidget {
  /// 0.0 – 1.0
  final double progress;
  final double size;
  final double strokeWidth;
  final List<Color> colors;
  final Widget?     centerChild;

  const GlowingNeonProgressRing({
    super.key,
    required this.progress,
    this.size        = 160,
    this.strokeWidth = 10,
    this.colors      = const [Color(0xFF00D4FF), Color(0xFF7C3AED)],
    this.centerChild,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width:  size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress:    progress.clamp(0.0, 1.0),
                strokeWidth: strokeWidth,
                colors:      colors,
              ),
            ),
            if (centerChild != null) centerChild!,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double       progress;
  final double       strokeWidth;
  final List<Color>  colors;

  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    // ── Background track ────────────────────────────────────────────────────────────
    final trackPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color       = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // ── Neon glow layers ───────────────────────────────────────────────────────────
    // Draw a wide blurred arc first to simulate the neon glow bleed,
    // then draw the crisp foreground arc on top.
    final sweepAngle = 2 * math.pi * progress;
    const startAngle = -math.pi / 2; // start at 12 o’clock

    // Outer glow — wide stroke, low opacity
    final glowPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.8
      ..strokeCap   = StrokeCap.round
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8)
      ..shader      = SweepGradient(
          colors:     colors,
          startAngle: startAngle,
          endAngle:   startAngle + sweepAngle,
          tileMode:   TileMode.clamp,
        ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

    // Foreground crisp arc — the actual progress track
    final arcPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round
      ..shader      = SweepGradient(
          colors:     colors,
          startAngle: startAngle,
          endAngle:   startAngle + sweepAngle,
          tileMode:   TileMode.clamp,
        ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    // ── Tip dot ─────────────────────────────────────────────────────────────────────────
    // A small glowing dot at the arc tip makes the progress feel alive.
    final tipAngle = startAngle + sweepAngle;
    final tipX     = center.dx + radius * math.cos(tipAngle);
    final tipY     = center.dy + radius * math.sin(tipAngle);
    final tipColor = colors.last;

    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth * 0.65,
      Paint()
        ..color      = tipColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth * 0.45,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
