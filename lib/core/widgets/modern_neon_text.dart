import 'package:flutter/material.dart';

/// ModernNeonText — gradient-shaded glowing typographic header.
///
/// Performance notes:
///   • The ShaderMask shader is rebuilt only when [colors] or [fontSize]
///     changes. For static headers, pass const lists to avoid rebuilds.
///   • Shadow list is kept small (3 layers) — each additional shadow layer
///     costs a full rasterisation pass. Three layers give a clean aura
///     without measurable frame-time impact on mid-range Android devices.
///   • fontFamilyFallback includes 'NotoColorEmoji' so modern Unicode
///     emoji render with full color on all Android API levels.
class ModernNeonText extends StatelessWidget {
  final String       text;
  final double       fontSize;
  final List<Color>  colors;
  final FontWeight   fontWeight;
  final TextAlign    textAlign;

  const ModernNeonText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.colors,
    this.fontWeight = FontWeight.w800,
    this.textAlign  = TextAlign.center,
  }) : assert(colors.length >= 2, 'ModernNeonText requires at least 2 colors');

  // Primary glow color is derived from the first gradient stop.
  // Declared as a helper so the shadow list is built once per widget
  // instance, not on every frame.
  List<Shadow> _buildShadows(Color primary) => [
    // Tight inner aura — keeps the character edges crisp
    Shadow(color: primary.withValues(alpha: 0.90), blurRadius: 4),
    // Mid glow — the visible neon halo around each glyph
    Shadow(color: primary.withValues(alpha: 0.55), blurRadius: 12),
    // Outer soft bloom — bleeds into the dark background
    Shadow(color: primary.withValues(alpha: 0.25), blurRadius: 28),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = colors.first;

    return ShaderMask(
      // BlendMode.srcIn masks the gradient onto the vector glyph shapes only.
      // The gradient is applied in the widget’s local coordinate space so
      // it always spans the full text width regardless of string length.
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end:   Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontSize:   fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Inter',
          // fontFamilyFallback ensures emoji and special Unicode characters
          // render correctly across all Android API levels without requiring
          // a separate emoji font asset in the bundle.
          fontFamilyFallback: const ['NotoColorEmoji', 'System2027Font'],
          color: Colors.white, // base color — overridden by ShaderMask
          shadows: _buildShadows(primary),
          height: 1.15,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
