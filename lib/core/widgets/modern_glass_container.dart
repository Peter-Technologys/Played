import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted-glass panel.
/// ClipRRect MUST wrap BackdropFilter to prevent blur bleeding outside
/// the rounded corners and causing full-screen jank.
class ModernGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color  tintColor;
  final double tintOpacity;
  final EdgeInsetsGeometry padding;
  final Border? border;

  const ModernGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.tintColor    = Colors.white,
    this.tintOpacity  = 0.07,
    this.padding      = const EdgeInsets.all(16),
    this.border,
  });

  // Static filter — allocated once, reused on every build.
  static final _filter = ImageFilter.blur(sigmaX: 15, sigmaY: 15);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: _filter,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tintColor.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
