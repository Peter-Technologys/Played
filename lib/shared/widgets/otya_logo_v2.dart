import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Canonical Otya lockup.
///
/// The product mark is now a simple modern media O: one strong blue ring with
/// a forward play cut. Next keeps its separate three-ball identity.
class OtyaLogo extends StatelessWidget {
  const OtyaLogo({
    super.key,
    this.fontSize = 30,
    this.letterSpacing = -.6,
    this.borderRadius = 16,
    this.padding = EdgeInsets.zero,
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
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mark,
          SizedBox(width: fontSize * .10),
          Text(
            'tya',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w750,
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

class OtyaMark extends StatelessWidget {
  const OtyaMark({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Otya',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: const CustomPaint(painter: _OtyaProductPainter()),
        ),
      );
}

/// Kept for direct legacy imports. Assistant surfaces should use
/// OtyaThinkingMark from otya_ai_mark.dart instead.
class OtyaThinkingMark extends StatelessWidget {
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
  Widget build(BuildContext context) => OtyaMark(size: size);
}

class _OtyaProductPainter extends CustomPainter {
  const _OtyaProductPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final outer = Path()..addOval(Rect.fromCircle(center: center, radius: side * .43));
    final inner = Path()..addOval(Rect.fromCircle(center: center, radius: side * .235));
    final playCut = Path()
      ..moveTo(center.dx - side * .015, center.dy - side * .17)
      ..lineTo(center.dx + side * .31, center.dy)
      ..lineTo(center.dx - side * .015, center.dy + side * .17)
      ..close();

    var mark = Path.combine(PathOperation.difference, outer, inner);
    mark = Path.combine(PathOperation.difference, mark, playCut);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      mark,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF68A6FF), Color(0xFF2979FF), Color(0xFF1767E8)],
          stops: [0, .5, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _OtyaProductPainter oldDelegate) => false;
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .58),
            fontFamily: 'Inter',
            letterSpacing: .3,
          ),
        ),
      );
}
