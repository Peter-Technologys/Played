import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension BuildContextX on BuildContext {
  /// Navigate to a named route.
  void goTo(String path, {Object? extra}) => go(path, extra: extra);

  /// Push a route on top of the current stack.
  void pushTo(String path, {Object? extra}) => push(path, extra: extra);

  /// Screen width shorthand.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Screen height shorthand.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// True when the device is in landscape orientation.
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  /// Safe area top padding.
  double get topPadding => MediaQuery.of(this).padding.top;

  /// Safe area bottom padding.
  double get bottomPadding => MediaQuery.of(this).padding.bottom;

  /// Show a quick snackbar.
  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.redAccent : const Color(0xFF111827),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
