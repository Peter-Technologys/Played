import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Canonical in-app Otya brand lockup.
///
/// The O symbol is the first letter of the name, so the horizontal lockup is
/// always the mark followed by lowercase `tya` — never a duplicated O.
class OtyaLogo extends StatelessWidget {
  const OtyaLogo({
    super.key,
    this.fontSize = 30,
    this.letterSpacing = -.6,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.iconOnly = false,
  });

  final double fontSize;
  final double letterSpacing;
  final double borderRadius;
  final EdgeInsets padding;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final mark = OtyaMark(size: fontSize * 1.18);
    if (iconOnly) return mark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardOf(context).withValues(alpha: .82),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mark,
          SizedBox(width: fontSize * .08),
          Text(
            'tya',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
              fontFamily: 'Inter',
              letterSpacing: letterSpacing,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Official static Otya mark.
///
/// The logo never spins in normal UI. The three resting balls are part of the
/// static identity. [OtyaThinkingMark] is the only animated variant.
class OtyaMark extends StatelessWidget {
  const OtyaMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    final darkSurface = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Otya',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _OtyaMarkPainter(
            darkSurface: darkSurface,
            thinkingProgress: null,
          ),
        ),
      ),
    );
  }
}

/// The Ask Otya thinking state.
///
/// The O itself stays fixed. Only the blue, red and yellow balls travel around
/// the curved inner route. When [thinking] becomes false the widget returns to
/// the exact static mark rather than leaving the balls in an arbitrary place.
class OtyaThinkingMark extends StatefulWidget {
  const OtyaThinkingMark({
    super.key,
    this.size = 52,
    this.thinking = true,
    this.duration = const Duration(milliseconds: 1800),
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
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.thinking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.thinking && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
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
  Widget build(BuildContext context) {
    final darkSurface = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: widget.thinking ? 'Otya is thinking' : 'Otya',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _OtyaMarkPainter(
              darkSurface: darkSurface,
              thinkingProgress: widget.thinking ? _controller.value : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _OtyaMarkPainter extends CustomPainter {
  const _OtyaMarkPainter({
    required this.darkSurface,
    required this.thinkingProgress,
  });

  final bool darkSurface;
  final double? thinkingProgress;

  static Path _topLobe() => Path()
    ..moveTo(160, 98)
    ..lineTo(138, 117)
    ..lineTo(116, 146)
    ..lineTo(100, 179)
    ..lineTo(89, 220)
    ..lineTo(108, 180)
    ..lineTo(129, 158)
    ..lineTo(141, 150)
    ..lineTo(165, 140)
    ..lineTo(186, 136)
    ..lineTo(211, 136)
    ..lineTo(241, 142)
    ..lineTo(270, 155)
    ..lineTo(292, 171)
    ..lineTo(315, 196)
    ..lineTo(327, 216)
    ..lineTo(337, 248)
    ..lineTo(338, 280)
    ..lineTo(333, 307)
    ..lineTo(324, 329)
    ..lineTo(354, 307)
    ..lineTo(373, 286)
    ..lineTo(389, 262)
    ..lineTo(402, 231)
    ..lineTo(406, 209)
    ..lineTo(405, 183)
    ..lineTo(399, 159)
    ..lineTo(373, 120)
    ..lineTo(350, 99)
    ..lineTo(330, 86)
    ..lineTo(303, 74)
    ..lineTo(272, 67)
    ..lineTo(240, 67)
    ..lineTo(211, 73)
    ..lineTo(181, 85)
    ..close();

  static Path _leftLobe() => Path()
    ..moveTo(180, 142)
    ..lineTo(159, 147)
    ..lineTo(139, 157)
    ..lineTo(116, 177)
    ..lineTo(105, 192)
    ..lineTo(89, 232)
    ..lineTo(89, 283)
    ..lineTo(102, 328)
    ..lineTo(113, 349)
    ..lineTo(133, 376)
    ..lineTo(152, 395)
    ..lineTo(174, 409)
    ..lineTo(191, 414)
    ..lineTo(219, 414)
    ..lineTo(249, 405)
    ..lineTo(276, 389)
    ..lineTo(298, 368)
    ..lineTo(316, 338)
    ..lineTo(285, 355)
    ..lineTo(267, 359)
    ..lineTo(247, 359)
    ..lineTo(216, 348)
    ..lineTo(192, 325)
    ..lineTo(181, 305)
    ..lineTo(173, 272)
    ..lineTo(175, 239)
    ..lineTo(188, 207)
    ..lineTo(209, 185)
    ..lineTo(236, 172)
    ..lineTo(264, 169)
    ..lineTo(291, 175)
    ..lineTo(273, 162)
    ..lineTo(242, 148)
    ..lineTo(215, 142)
    ..close();

  static Path _rightLobe() => Path()
    ..moveTo(405, 164)
    ..lineTo(410, 190)
    ..lineTo(408, 224)
    ..lineTo(395, 260)
    ..lineTo(373, 293)
    ..lineTo(348, 318)
    ..lineTo(321, 337)
    ..lineTo(301, 371)
    ..lineTo(269, 399)
    ..lineTo(248, 410)
    ..lineTo(226, 417)
    ..lineTo(184, 417)
    ..lineTo(210, 428)
    ..lineTo(234, 433)
    ..lineTo(256, 434)
    ..lineTo(289, 430)
    ..lineTo(320, 420)
    ..lineTo(343, 408)
    ..lineTo(382, 374)
    ..lineTo(412, 329)
    ..lineTo(423, 298)
    ..lineTo(427, 275)
    ..lineTo(428, 246)
    ..lineTo(425, 220)
    ..lineTo(417, 190)
    ..close();

  static Path _topLeftSeam() => Path()
    ..moveTo(107, 180)
    ..cubicTo(150, 121, 236, 120, 292, 171);

  static Path _topRightSeam() => Path()
    ..moveTo(324, 329)
    ..cubicTo(350, 295, 383, 267, 402, 231);

  static Path _lowerSeam() => Path()
    ..moveTo(184, 417)
    ..cubicTo(236, 414, 278, 390, 316, 338);

  Color get _front =>
      darkSurface ? const Color(0xFFFCFCFC) : const Color(0xFF101114);
  Color get _mid =>
      darkSurface ? const Color(0xFFE4E4E7) : const Color(0xFF25262B);
  Color get _shade =>
      darkSurface ? const Color(0xFFBFC0C5) : const Color(0xFF44464D);
  Color get _seam =>
      darkSurface ? const Color(0xFF090A0D) : const Color(0xFF020306);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 512;
    canvas.save();
    canvas.scale(scale, scale);

    final top = _topLobe();
    final left = _leftLobe();
    final right = _rightLobe();

    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_front, _mid, _front],
        ).createShader(const Rect.fromLTWH(70, 55, 360, 300)),
    );
    canvas.drawPath(
      left,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_mid, _front, _shade],
        ).createShader(const Rect.fromLTWH(70, 130, 270, 310)),
    );

    // Thin contour seams stay fixed on the O in both static and thinking states.
    // They visually separate the interlocking ribbon sections without changing
    // the brand colours or making the entire mark rotate.
    final seamPaint = Paint()
      ..color = _seam.withValues(alpha: darkSurface ? .92 : .82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_topLeftSeam(), seamPaint);
    canvas.drawPath(_lowerSeam(), seamPaint);

    // Balls live inside the O. In normal branding they are fixed in the
    // approved resting position. During Ask Otya thinking they move together
    // around the full curved route while the O itself remains completely still.
    if (thinkingProgress == null) {
      _drawBall(
        canvas,
        const Offset(310, 310),
        18,
        darkSurface ? const Color(0xFF202124) : const Color(0xFFF4F4F5),
      );
      _drawBall(
        canvas,
        const Offset(335, 292),
        19,
        darkSurface ? Colors.white : const Color(0xFF15161A),
      );
      _drawBall(
        canvas,
        const Offset(356, 267),
        18,
        darkSurface ? const Color(0xFF202124) : const Color(0xFFF4F4F5),
      );
    } else {
      final baseAngle = thinkingProgress! * math.pi * 2 + .68;
      const colors = <Color>[
        Color(0xFF2979FF),
        Color(0xFFFF3B30),
        Color(0xFFFFD60A),
      ];
      for (var i = 0; i < colors.length; i++) {
        final angle = baseAngle - i * .19;
        final point = Offset(
          256 + math.cos(angle) * 112,
          256 + math.sin(angle) * 126,
        );
        _drawBall(canvas, point, 17, colors[i]);
      }
    }

    // The right lobe is intentionally painted last so the balls disappear
    // behind the overlap for part of their journey, making the route feel like
    // it passes through the ribbon instead of floating on top of it.
    canvas.drawPath(
      right,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [_shade, _front, _mid],
        ).createShader(const Rect.fromLTWH(170, 150, 280, 300)),
    );
    canvas.drawPath(_topRightSeam(), seamPaint);

    canvas.restore();
  }

  void _drawBall(Canvas canvas, Offset center, double radius, Color color) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(2, 4), radius, shadow);

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.45),
          radius: .95,
          colors: [
            Colors.white.withValues(alpha: .9),
            color,
            Color.lerp(color, Colors.black, .28)!,
          ],
          stops: const [0, .34, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _OtyaMarkPainter oldDelegate) =>
      oldDelegate.darkSurface != darkSurface ||
      oldDelegate.thinkingProgress != thinkingProgress;
}

class OtyaFooter extends StatelessWidget {
  const OtyaFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Otya',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: .58),
            fontFamily: 'Inter',
            letterSpacing: .3,
          ),
        ),
      );
}
