import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Offline-first default OTYA backdrop.
///
/// Drawn entirely in Flutter so the app ships with its own distinctive
/// mountain-and-lake identity without depending on a network image or a
/// third-party wallpaper asset. A user-selected Image Theme can still replace
/// this background globally.
class OtyaMountainBackground extends StatelessWidget {
  final double darkness;
  final bool showGlow;

  const OtyaMountainBackground({
    super.key,
    this.darkness = 0.34,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _MountainLakePainter()),
          if (showGlow)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.36, -0.28),
                  radius: 1.0,
                  colors: [Color(0x528B5CF6), Color(0x008B5CF6)],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: darkness * 0.45),
                  Colors.black.withValues(alpha: darkness * 0.22),
                  Colors.black.withValues(alpha: darkness),
                  const Color(0xF308080B),
                ],
                stops: const [0, 0.32, 0.72, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MountainLakePainter extends CustomPainter {
  const _MountainLakePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.48;

    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF080812),
          Color(0xFF17112C),
          Color(0xFF4C1D72),
          Color(0xFF8B3F92),
          Color(0xFF281632),
        ],
        stops: [0, 0.28, 0.58, 0.78, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, horizon));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizon), sky);

    final lake = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF241633), Color(0xFF100D1C), Color(0xFF07080D)],
      ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon));
    canvas.drawRect(Rect.fromLTWH(0, horizon, w, h - horizon), lake);

    _drawRange(
      canvas,
      size,
      horizon,
      color: const Color(0xFF2E2341),
      peaks: const [
        [0.00, 0.72], [0.10, 0.61], [0.18, 0.70], [0.28, 0.47],
        [0.39, 0.65], [0.53, 0.43], [0.61, 0.61], [0.72, 0.38],
        [0.80, 0.59], [0.91, 0.45], [1.00, 0.68]
      ],
    );

    _drawRange(
      canvas,
      size,
      horizon,
      color: const Color(0xFF151524),
      peaks: const [
        [0.00, 0.82], [0.13, 0.73], [0.24, 0.77], [0.35, 0.62],
        [0.46, 0.75], [0.57, 0.56], [0.69, 0.72], [0.82, 0.59],
        [1.00, 0.79]
      ],
      yScale: 0.83,
    );

    _drawSnow(canvas, size, horizon);
    _drawReflection(canvas, size, horizon);
    _drawTrees(canvas, size, horizon);
  }

  void _drawRange(
    Canvas canvas,
    Size size,
    double horizon, {
    required Color color,
    required List<List<double>> peaks,
    double yScale = 1,
  }) {
    final p = Path()..moveTo(0, horizon);
    for (final point in peaks) {
      final x = point[0] * size.width;
      final y = horizon - (1 - point[1]) * size.height * 0.34 * yScale;
      p.lineTo(x, y);
    }
    p.lineTo(size.width, horizon);
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _drawSnow(Canvas canvas, Size size, double horizon) {
    final paint = Paint()..color = const Color(0x55E7DDFD);
    final peaks = [
      Offset(size.width * 0.28, horizon - size.height * 0.18),
      Offset(size.width * 0.53, horizon - size.height * 0.19),
      Offset(size.width * 0.72, horizon - size.height * 0.21),
      Offset(size.width * 0.91, horizon - size.height * 0.18),
    ];
    for (final peak in peaks) {
      final path = Path()
        ..moveTo(peak.dx, peak.dy)
        ..lineTo(peak.dx - size.width * 0.035, peak.dy + size.height * 0.045)
        ..lineTo(peak.dx - size.width * 0.006, peak.dy + size.height * 0.032)
        ..lineTo(peak.dx + size.width * 0.016, peak.dy + size.height * 0.054)
        ..lineTo(peak.dx + size.width * 0.046, peak.dy + size.height * 0.042)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawReflection(Canvas canvas, Size size, double horizon) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x408B5CF6), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.52, horizon + size.height * 0.13),
          radius: math.max(size.width, size.height) * 0.34,
        ),
      );
    canvas.drawRect(Rect.fromLTWH(0, horizon, size.width, size.height - horizon), glow);

    final linePaint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x288B5CF6);
    for (var i = 0; i < 8; i++) {
      final y = horizon + size.height * (0.045 + i * 0.028);
      final width = size.width * (0.10 + i * 0.025);
      canvas.drawLine(
        Offset(size.width * 0.52 - width, y),
        Offset(size.width * 0.52 + width, y),
        linePaint,
      );
    }
  }

  void _drawTrees(Canvas canvas, Size size, double horizon) {
    final paint = Paint()..color = const Color(0xFF080A10);
    for (var i = 0; i < 18; i++) {
      final t = i / 17;
      final x = size.width * (i.isEven ? t * 0.22 : 0.78 + t * 0.22);
      final baseY = horizon + size.height * (0.025 + (i % 4) * 0.008);
      final treeH = size.height * (0.035 + (i % 5) * 0.012);
      final trunk = Path()
        ..moveTo(x, baseY - treeH)
        ..lineTo(x - treeH * 0.28, baseY)
        ..lineTo(x + treeH * 0.28, baseY)
        ..close();
      canvas.drawPath(trunk, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
