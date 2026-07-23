import 'package:flutter/material.dart';

/// Responsive layout helpers for universal device support.
///
/// Covers phones (small/normal/large), tablets, foldables, and Chromebooks.
/// All values are derived from [MediaQuery] so they adapt to any screen.
abstract class Responsive {
  /// Returns true when the shortest side of the screen is >= 600 dp.
  /// This matches Android's definition of a "large" screen / tablet.
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  /// Returns true on very small phones (e.g. 4" devices, height < 640 dp).
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.height < 640;

  /// Returns true on medium phones (height 640–720 dp).
  static bool isMediumPhone(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return h >= 640 && h < 720;
  }

  /// Horizontal padding that scales with screen width.
  /// Phones: 16 dp · Tablets: 32 dp · Large tablets: 64 dp.
  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1024) return 64;
    if (w >= 600)  return 32;
    return 16;
  }

  /// Font scale clamped to [0.85, 1.3] so text never overflows on
  /// devices with large system font sizes (common on Vivo, Oppo, Xiaomi).
  static double clampedTextScale(BuildContext context) =>
      MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.3);

  /// Returns a value that scales linearly between [small], [normal], and
  /// [large] based on the screen's shortest side.
  static double adaptiveValue(
    BuildContext context, {
    required double small,
    required double normal,
    double? large,
  }) {
    final side = MediaQuery.of(context).size.shortestSide;
    if (side < 360) return small;
    if (side < 600) return normal;
    return large ?? normal * 1.4;
  }

  /// Safe bottom padding that accounts for gesture navigation bars,
  /// notches, and rounded corners on all OEM skins.
  static double safeBottom(BuildContext context) =>
      MediaQuery.of(context).padding.bottom + 8;

  /// Maximum content width for tablet/desktop layouts.
  /// Content is centred within this width on large screens.
  static const double maxContentWidth = 720;

  /// Wraps [child] in a centred, width-constrained box on large screens.
  static Widget constrained(BuildContext context, Widget child) {
    if (!isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}

/// A [MediaQuery] wrapper that clamps [textScaler] to prevent overflow
/// on OEM skins (Vivo, Oppo, Samsung One UI) that default to large fonts.
///
/// Wrap your [MaterialApp] builder with this widget:
/// ```dart
/// builder: (context, child) => ClampedTextScale(child: child!),
/// ```
class ClampedTextScale extends StatelessWidget {
  final Widget child;
  const ClampedTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final clampedScale = mq.textScaler.scale(1.0).clamp(0.85, 1.3);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(clampedScale),
      ),
      child: child,
    );
  }
}
