// lib/shared/widgets/wallpaper_scaffold.dart
//
// WallpaperScaffold — the visual foundation for OTYA's image-first UI.
// It keeps every screen readable over user-selected artwork while preserving
// the OTYA visual identity.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/custom_theme_manager.dart';
import 'otya_mountain_background.dart';
import 'story_theme_background.dart';

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
        final manager = CustomThemeManager.instance;
        final wallpaperPath = manager.wallpaperPath;
        final hasWallpaper = manager.hasImageWallpaper;
        final storyTheme = manager.storyTheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Keep Android system bars visually attached to the active OTYA
        // background. SafeArea remains the responsibility of each screen, but
        // the navigation/status regions no longer become unrelated opaque bars.
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark || hasWallpaper
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: isDark || hasWallpaper
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark || hasWallpaper
              ? Brightness.light
              : Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasWallpaper && wallpaperPath != null)
                _ImageThemeBackground(
                  path: wallpaperPath,
                  dimAmount: manager.artOpacity,
                  blur: manager.artBlur,
                )
              else if (storyTheme != null)
                StoryThemeBackground(theme: storyTheme)
              else
                const OtyaMountainBackground(),
              Scaffold(
                backgroundColor: backgroundColor ?? Colors.transparent,
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
          ),
        );
      },
    );
  }
}

class _ImageThemeBackground extends StatelessWidget {
  const _ImageThemeBackground({
    required this.path,
    required this.dimAmount,
    required this.blur,
  });

  final String path;
  final double dimAmount;
  final double blur;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.file(
      File(path),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const OtyaMountainBackground(),
    );

    if (blur > 0) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Transform.scale(scale: 1.04, child: image),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: const Color(0xFF08080B), child: image),
        ColoredBox(
          color: Colors.black.withValues(alpha: dimAmount.clamp(0.18, 0.70)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x5208080B),
                Color(0x1208080B),
                Color(0x9A08080B),
              ],
              stops: [0.0, 0.48, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -140,
          right: -100,
          child: IgnorePointer(
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.20),
                    AppColors.accent.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
