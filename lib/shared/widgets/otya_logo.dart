import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Canonical in-app OTYA brand lockup.
///
/// The symbol geometry is shared with the approved OTYA brand pack. Visible
/// product branding must never fall back to a generic play mark or plain ring.
class OtyaLogo extends StatelessWidget {
  const OtyaLogo({
    super.key,
    this.fontSize = 30,
    this.letterSpacing = 2.4,
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
        children: [
          mark,
          SizedBox(width: fontSize * .34),
          Text(
            'TYA',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
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

/// Official OTYA twisted-O symbol.
///
/// These three lobes are traced from the approved master symbol supplied in
/// the OTYA brand pack. The canvas is 512x512 to keep the geometry identical
/// across Flutter and Android vector resources.
class OtyaMark extends StatelessWidget {
  const OtyaMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'OTYA',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: const _OtyaMarkPainter()),
        ),
      );
}

class _OtyaMarkPainter extends CustomPainter {
  const _OtyaMarkPainter();

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
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18D8FF), Color(0xFF146BFF), Color(0xFF6A19FF)],
        ).createShader(const Rect.fromLTWH(70, 55, 360, 300)),
    );
    canvas.drawPath(
      left,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF146BFF), Color(0xFF6A19FF), Color(0xFFE81CFF)],
        ).createShader(const Rect.fromLTWH(70, 130, 270, 310)),
    );
    canvas.drawPath(
      right,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFFE81CFF), Color(0xFFFF5B58), Color(0xFFFFB000)],
        ).createShader(const Rect.fromLTWH(170, 150, 280, 300)),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OtyaMarkPainter oldDelegate) => false;
}

class OtyaFooter extends StatelessWidget {
  const OtyaFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'OTYA · PeterSmart Link',
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
