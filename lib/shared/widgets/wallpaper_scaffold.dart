// lib/shared/widgets/wallpaper_scaffold.dart
//
// WallpaperScaffold — wraps Scaffold and applies the user's wallpaper (if set)
// as the background via CustomThemeManager.
//
// Falls back to the theme's scaffoldBackgroundColor when no wallpaper is set.
// The wallpaper image has a 55% dark overlay applied by CustomThemeManager so
// text remains readable regardless of the image content.
//
// Usage:
//   WallpaperScaffold(
//     appBar: AppBar(...),
//     body: MyContent(),
//   )

import 'package:flutter/material.dart';
import '../../core/services/custom_theme_manager.dart';

class WallpaperScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  const WallpaperScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    // Listen to CustomThemeManager so the scaffold rebuilds when the
    // wallpaper changes. CustomThemeManager is a ChangeNotifier — wrap in
    // AnimatedBuilder to subscribe without a ChangeNotifierProvider.
    return AnimatedBuilder(
      animation: CustomThemeManager.instance,
      builder: (context, _) {
        final wallpaper = CustomThemeManager.instance.wallpaperDecoration;
        final effectiveBg = backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor;

        if (wallpaper == null) {
          // No wallpaper — plain Scaffold with theme background.
          return Scaffold(
            backgroundColor: effectiveBg,
            appBar: appBar,
            body: body,
            bottomNavigationBar: bottomNavigationBar,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            extendBody: extendBody,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          );
        }

        // Wallpaper is set — use a transparent Scaffold over a full-screen
        // wallpaper Container so the image shows through.
        return Stack(
          fit: StackFit.expand,
          children: [
            // Wallpaper layer (behind everything)
            Container(
              decoration: BoxDecoration(image: wallpaper),
            ),
            // Scaffold with transparent background so the wallpaper shows
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: appBar,
              body: body,
              bottomNavigationBar: bottomNavigationBar,
              floatingActionButton: floatingActionButton,
              floatingActionButtonLocation: floatingActionButtonLocation,
              extendBodyBehindAppBar: extendBodyBehindAppBar,
              extendBody: extendBody,
              resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            ),
          ],
        );
      },
    );
  }
}
