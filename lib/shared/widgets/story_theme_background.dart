import 'dart:math' as math;

import 'package:flutter/material.dart';

class StoryThemeBackground extends StatelessWidget {
  const StoryThemeBackground({
    super.key,
    required this.theme,
  });

  final Map<String, dynamic> theme;

  @override
  Widget build(BuildContext context) {
    final scene = theme['scene'] as String? ?? 'mountain_lake';
    final palette = (theme['palette'] as Map<String, dynamic>? ?? const {})
        .map((key, value) => MapEntry(key, value.toString()));
    final overlay = ((theme['overlay'] as num?)?.toDouble() ?? 0.38)
        .clamp(0.18, 0.70);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _StoryPainter(scene: scene, palette: palette),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: overlay)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x16000000),
                  Color(0x00000000),
                  Color(0x6A000000),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryPainter extends CustomPainter {
  _StoryPainter({required this.scene, required this.palette});

  final String scene;
  final Map<String, String> palette;

  Color _color(String key, Color fallback) {
    final raw = palette[key];
    if (raw == null) return fallback;
    final cleaned = raw.replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final skyTop = _color('skyTop', const Color(0xFF150B2E));
    final skyMid = _color('skyMid', const Color(0xFF4C1D95));
    final horizon = _color('horizon', const Color(0xFFA855F7));
    final land = _color('land', const Color(0xFF09070E));
    final water = _color('water', const Color(0xFF100B1D));
    final accent = _color('accent', const Color(0xFF8B5CF6));
    final warm = _color('warm', const Color(0xFFFDE68A));

    final horizonY = size.height * 0.48;
    final skyRect = Rect.fromLTWH(0, 0, size.width, horizonY + 70);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop, skyMid, horizon],
          stops: const [0, 0.63, 1],
        ).createShader(skyRect),
    );

    switch (scene) {
      case 'river_sunset':
        _paintRiver(canvas, size, horizonY, land, water, accent, horizon);
      case 'winter_lights':
        _paintMountains(canvas, size, horizonY, land, water, accent);
        _paintWinterLights(canvas, size, horizonY, warm, accent);
      case 'fireworks_lake':
        _paintMountains(canvas, size, horizonY, land, water, accent);
        _paintFireworks(canvas, size, horizonY, accent, warm);
      default:
        _paintMountains(canvas, size, horizonY, land, water, accent);
    }
  }

  void _paintMountains(
    Canvas canvas,
    Size size,
    double horizonY,
    Color land,
    Color water,
    Color accent,
  ) {
    final back = Path()
      ..moveTo(0, horizonY + 25)
      ..lineTo(size.width * 0.18, horizonY - 25)
      ..lineTo(size.width * 0.34, horizonY + 8)
      ..lineTo(size.width * 0.51, horizonY - size.height * 0.19)
      ..lineTo(size.width * 0.68, horizonY + 4)
      ..lineTo(size.width * 0.83, horizonY - 35)
      ..lineTo(size.width, horizonY + 15)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, Paint()..color = land.withValues(alpha: 0.86));

    final snow = Path()
      ..moveTo(size.width * 0.51, horizonY - size.height * 0.19)
      ..lineTo(size.width * 0.47, horizonY - size.height * 0.105)
      ..lineTo(size.width * 0.51, horizonY - size.height * 0.135)
      ..lineTo(size.width * 0.56, horizonY - size.height * 0.07)
      ..close();
    canvas.drawPath(snow, Paint()..color = accent.withValues(alpha: 0.33));

    final waterRect = Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY);
    canvas.drawRect(
      waterRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.20), water, land],
        ).createShader(waterRect),
    );

    for (var i = 0; i < 9; i++) {
      final y = horizonY + 18 + i * 28;
      final half = size.width * (0.38 - i * 0.025).clamp(0.12, 0.38);
      canvas.drawLine(
        Offset(size.width / 2 - half, y),
        Offset(size.width / 2 + half, y),
        Paint()
          ..color = accent.withValues(alpha: 0.08)
          ..strokeWidth = 1,
      );
    }
  }

  void _paintWinterLights(
    Canvas canvas,
    Size size,
    double horizonY,
    Color warm,
    Color accent,
  ) {
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < 34; i++) {
      final x = ((i * 53) % 101) / 101 * size.width;
      final y = 24 + (((i * 37) % 97) / 97) * horizonY * 0.58;
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.6 : 0.9, starPaint);
    }

    final lightPaint = Paint()
      ..color = warm.withValues(alpha: 0.92)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (var i = 0; i < 12; i++) {
      final x = size.width * (0.12 + (i * 0.067));
      final y = horizonY + 8 + (i % 3) * 7;
      canvas.drawCircle(Offset(x, y), 2.4, lightPaint);
    }

    final treePaint = Paint()..color = const Color(0xFF06080B).withValues(alpha: 0.94);
    for (var i = 0; i < 10; i++) {
      final x = size.width * (0.06 + i * 0.095);
      final base = horizonY + 26 + (i % 3) * 8;
      final h = 28.0 + (i % 4) * 8;
      final tree = Path()
        ..moveTo(x, base - h)
        ..lineTo(x - h * 0.26, base)
        ..lineTo(x + h * 0.26, base)
        ..close();
      canvas.drawPath(tree, treePaint);
    }

    canvas.drawCircle(
      Offset(size.width * 0.82, horizonY * 0.28),
      math.min(size.width, size.height) * 0.018,
      Paint()..color = accent.withValues(alpha: 0.40),
    );
  }

  void _paintFireworks(
    Canvas canvas,
    Size size,
    double horizonY,
    Color accent,
    Color warm,
  ) {
    void burst(Offset center, double radius, Color color, int rays) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.82)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < rays; i++) {
        final angle = (math.pi * 2 * i) / rays;
        final inner = radius * 0.22;
        final outer = radius * (0.72 + (i % 3) * 0.12);
        canvas.drawLine(
          Offset(center.dx + math.cos(angle) * inner, center.dy + math.sin(angle) * inner),
          Offset(center.dx + math.cos(angle) * outer, center.dy + math.sin(angle) * outer),
          paint,
        );
      }
      canvas.drawCircle(
        center,
        2.5,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    burst(Offset(size.width * 0.28, horizonY * 0.35), size.width * 0.11, accent, 18);
    burst(Offset(size.width * 0.70, horizonY * 0.27), size.width * 0.14, warm, 22);
    burst(Offset(size.width * 0.52, horizonY * 0.50), size.width * 0.075, Colors.white, 14);

    final reflectionPaint = Paint()
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: 0.18);
    for (var i = 0; i < 7; i++) {
      final y = horizonY + 22 + i * 24;
      canvas.drawLine(
        Offset(size.width * 0.34, y),
        Offset(size.width * 0.66, y),
        reflectionPaint,
      );
    }
  }

  void _paintRiver(
    Canvas canvas,
    Size size,
    double horizonY,
    Color land,
    Color water,
    Color accent,
    Color horizon,
  ) {
    final banks = Path()
      ..moveTo(0, horizonY - 10)
      ..quadraticBezierTo(size.width * 0.24, horizonY + 26, size.width * 0.38, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(banks, Paint()..color = land);

    final rightBank = Path()
      ..moveTo(size.width, horizonY - 6)
      ..quadraticBezierTo(size.width * 0.77, horizonY + 28, size.width * 0.63, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(rightBank, Paint()..color = land.withValues(alpha: 0.97));

    final river = Path()
      ..moveTo(size.width * 0.44, horizonY)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.72, size.width * 0.20, size.height)
      ..lineTo(size.width * 0.80, size.height)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.72, size.width * 0.56, horizonY)
      ..close();
    canvas.drawPath(
      river,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [horizon.withValues(alpha: 0.65), accent.withValues(alpha: 0.32), water],
        ).createShader(Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY)),
    );

    final reedPaint = Paint()
      ..color = land.withValues(alpha: 0.88)
      ..strokeWidth = 2;
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < 16; i++) {
        final x = side == 0
            ? 8 + i * size.width * 0.018
            : size.width - 8 - i * size.width * 0.018;
        final base = size.height * (0.72 + (i % 4) * 0.045);
        final height = 26 + (i % 5) * 8;
        canvas.drawLine(Offset(x, base), Offset(x + (side == 0 ? 4 : -4), base - height), reedPaint);
        canvas.drawCircle(
          Offset(x + (side == 0 ? 4 : -4), base - height),
          2.5,
          reedPaint,
        );
      }
    }

    final sun = Offset(size.width * 0.66, horizonY * 0.67);
    canvas.drawCircle(
      sun,
      math.min(size.width, size.height) * 0.035,
      Paint()..color = horizon.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _StoryPainter oldDelegate) =>
      scene != oldDelegate.scene || palette.toString() != oldDelegate.palette.toString();
}
