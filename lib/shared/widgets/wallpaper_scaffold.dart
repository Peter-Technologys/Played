// lib/shared/widgets/wallpaper_scaffold.dart
//
// WallpaperScaffold — wraps Scaffold and applies the user's wallpaper (if set)
// as the background via CustomThemeManager.
//
// Without a custom wallpaper OTYA uses a restrained ambient background instead
// of a single flat colour. This keeps screens visually layered without turning
// the UI into a collection of bright colour blocks.

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
    return AnimatedBuilder(
      animation: CustomThemeManager.instance,
      builder: (context, _) {
        final wallpaper = CustomThemeManager.instance.wallpaperDecoration;
        final effectiveBg = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

        if (wallpaper == null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: effectiveBg,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.055),
                        effectiveBg,
                      ),
                      effectiveBg,
                      Color.alphaBlend(
                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.04),
                        effectiveBg,
                      ),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: -120,
                right: -100,
                child: IgnorePointer(
                  child: Container(
                    width: 290,
                    height: 290,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -150,
                left: -110,
                child: IgnorePointer(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary.withValues(alpha: 0.055),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(image: wallpaper)),
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
