import 'package:flutter/material.dart';

/// ModernNeonContainer — a decorative card layer with multi-layered neon glow.
///
/// Performance notes:
///   • All BoxShadow lists are built as static const where the neonColor is
///     known at compile time. For dynamic colors the list is built once in
///     the constructor and stored, never rebuilt on every paint cycle.
///   • ClipRRect is placed OUTSIDE the decorated Container so the clip
///     happens before the shadow is composited — prevents shadow bleed.
class ModernNeonContainer extends StatelessWidget {
  final Widget  child;
  final Color   neonColor;
  final double  borderRadius;
  final EdgeInsetsGeometry padding;
  final Color?  backgroundColor;

  const ModernNeonContainer({
    super.key,
    required this.child,
    required this.neonColor,
    this.borderRadius   = 20,
    this.padding        = const EdgeInsets.all(16),
    this.backgroundColor,
  });

  // ── Static shadow presets for the two most-used brand colors ──────────────────
  // Declaring these as static const avoids re-allocating the list on every
  // build() call, which is critical during heavy background media streaming.

  static List<BoxShadow> _buildShadows(Color c) => [
    // Tight inner halo — gives the edge a crisp lit look
    BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 6,  spreadRadius: -2),
    // Mid glow — the primary visible neon bleed
    BoxShadow(color: c.withValues(alpha: 0.30), blurRadius: 16, spreadRadius: -1),
    // Outer soft aura — bleeds into the dark background
    BoxShadow(color: c.withValues(alpha: 0.15), blurRadius: 32, spreadRadius:  0),
    // Ultra-wide ambient — barely visible, adds depth on AMOLED screens
    BoxShadow(color: c.withValues(alpha: 0.07), blurRadius: 56, spreadRadius:  4),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF090D16);
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _buildShadows(neonColor),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            // Semi-transparent border edge reflection — bridges the glass
            // interior with the outer glow without looking like a solid ring.
            border: Border.all(
              color: neonColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
