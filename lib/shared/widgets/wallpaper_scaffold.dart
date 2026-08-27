// lib/shared/widgets/wallpaper_scaffold.dart
//
// WallpaperScaffold — the visual foundation for OTYA's image-first UI.
// It keeps every screen readable over user-selected artwork while preserving
// the PeterSmart Link / OTYA purple identity.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
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
        final manager = CustomThemeManager.instance;
        final wallpaperPath = manager.wallpaperPath;
        final hasWallpaper = wallpaperPath != null && File(wallpaperPath).existsSync();
        final effectiveBg = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasWallpaper)
              _ImageThemeBackground(
                path: wallpaperPath,
                dimAmount: manager.artOpacity,
                blur: manager.artBlur,
              )
            else
              _OtyaAmbientBackground(background: effectiveBg),
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
        // The image is intentionally visible. These layers are only for text
        // contrast, not to hide the selected artwork.
        ColoredBox(color: Colors.black.withValues(alpha: dimAmount.clamp(0.18, 0.70))),
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

class _OtyaAmbientBackground extends StatelessWidget {
  const _OtyaAmbientBackground({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF100C18),
                Color(0xFF08080B),
                Color(0xFF0B0910),
              ],
              stops: [0.0, 0.52, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -110,
          right: -90,
          child: IgnorePointer(
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.22),
                    AppColors.accent.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -170,
          left: -130,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5B21B6).withValues(alpha: 0.13),
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
