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

    if (scene == 'river_sunset') {
      _paintRiver(canvas, size, horizonY, land, water, accent, horizon);
    } else {
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
