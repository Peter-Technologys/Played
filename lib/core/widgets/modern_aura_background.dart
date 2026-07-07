import 'package:flutter/material.dart';

/// Deep charcoal background with two floating gradient orbs.
/// No external image assets — pure Flutter rendering primitives.
class ModernAuraBackground extends StatelessWidget {
  final Widget child;
  const ModernAuraBackground({super.key, required this.child});

  static const Color _bg = Color(0xFF090D16);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        Container(color: _bg),
        Positioned(
          left: -size.width * 0.25, top: -size.height * 0.1,
          child: _Orb(size: size.width * 0.8, color: const Color(0xFF00D4FF)),
        ),
        Positioned(
          right: -size.width * 0.3, bottom: -size.height * 0.15,
          child: _Orb(size: size.width * 0.9, color: const Color(0xFF7C3AED)),
        ),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color  color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: 0.18), Colors.transparent],
      ),
    ),
  );
}
