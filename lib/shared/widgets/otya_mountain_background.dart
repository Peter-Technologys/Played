import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Offline-first default Otya backdrop.
///
/// The historical class name is retained for source compatibility, but the
/// visual is now derived from Otya's current cyan/blue flowing mark rather than
/// a scenic mountain wallpaper. It is painted locally, adds no network work,
/// and user-selected Image/Story themes still replace it through
/// WallpaperScaffold.
class OtyaMountainBackground extends StatelessWidget {
  final double darkness;
  final bool showGlow;

  const OtyaMountainBackground({
    super.key,
    this.darkness = 0.30,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.background),
          const CustomPaint(painter: _OtyaLightFlowPainter()),
          if (showGlow)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.72, -0.68),
                  radius: 1.05,
                  colors: [
                    Color(0x3D27E8FF),
                    Color(0x22126BFF),
                    Color(0x00126BFF),
                  ],
                  stops: [0, .42, 1],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: darkness * .12),
                  Colors.transparent,
                  Colors.black.withValues(alpha: darkness * .38),
                  const Color(0xD9050812),
                ],
                stops: const [0, .36, .74, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtyaLightFlowPainter extends CustomPainter {
  const _OtyaLightFlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);

    // A restrained top-right ribbon echoes the current Otya mark without
    // placing a literal logo behind content.
    final topPath = Path()
      ..moveTo(size.width * .72, -shortest * .10)
      ..cubicTo(
        size.width * .96,
        size.height * .08,
        size.width * 1.02,
        size.height * .18,
        size.width * .86,
        size.height * .30,
      )
      ..cubicTo(
        size.width * .74,
        size.height * .38,
        size.width * .73,
        size.height * .48,
        size.width * .96,
        size.height * .56,
      );

    final topPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * .16
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [
          Color(0x0027E8FF),
          Color(0x6127E8FF),
          Color(0x66126BFF),
          Color(0x00173BFF),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(topPath, topPaint);

    // Lower-left counter-flow keeps large screens from feeling empty while
    // staying subtle behind lists and playback controls.
    final lowerPath = Path()
      ..moveTo(-shortest * .18, size.height * .82)
      ..cubicTo(
        size.width * .12,
        size.height * .67,
        size.width * .30,
        size.height * .68,
        size.width * .42,
        size.height * .84,
      )
      ..cubicTo(
        size.width * .52,
        size.height * .98,
        size.width * .68,
        size.height * 1.01,
        size.width * .82,
        size.height * .94,
      );
    final lowerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * .12
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [
          Color(0x00173BFF),
          Color(0x45126BFF),
          Color(0x3827E8FF),
          Color(0x00126BFF),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(lowerPath, lowerPaint);

    // Fine hairline gives the backdrop definition without becoming a neon
    // wallpaper. It is decorative only and never animates.
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.brandCyan.withValues(alpha: .13);
    canvas.drawPath(topPath, hairline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}