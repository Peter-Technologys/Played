import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable OTYA brand mark.
///
/// The logo geometry stays unchanged. Motion is applied around the canonical
/// asset so the same mark can represent idle, listening, thinking, responding,
/// success and offline/error states without inventing alternate logos.
class OtyaBrandMark extends StatefulWidget {
  final double size;
  final bool animate;
  final OtyaBrandState state;
  final String assetPath;

  const OtyaBrandMark({
    super.key,
    this.size = 88,
    this.animate = false,
    this.state = OtyaBrandState.idle,
    this.assetPath = 'assets/icons/otya_logo_master.png',
  });

  @override
  State<OtyaBrandMark> createState() => _OtyaBrandMarkState();
}

enum OtyaBrandState { idle, listening, thinking, responding, success, offline }

class _OtyaBrandMarkState extends State<OtyaBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant OtyaBrandMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      widget.animate ? _controller.repeat() : _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = widget.animate && !reducedMotion;

    Widget logo = Image.asset(
      widget.assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'OTYA',
    );

    if (widget.state == OtyaBrandState.offline) {
      logo = Opacity(opacity: .56, child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFF8B8FA4), BlendMode.saturation),
        child: logo,
      ));
    }

    if (!shouldAnimate) return logo;

    return AnimatedBuilder(
      animation: _controller,
      child: logo,
      builder: (context, child) {
        final t = _controller.value;
        final pulse = 1 + .035 * math.sin(t * math.pi * 2);
        final intensity = switch (widget.state) {
          OtyaBrandState.listening => .22,
          OtyaBrandState.thinking => .34,
          OtyaBrandState.responding => .28,
          OtyaBrandState.success => .38,
          _ => .18,
        };
        return Transform.scale(
          scale: pulse,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * .92,
                height: widget.size * .92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(
                            const Color(0xFF146BFF),
                            const Color(0xFFE81CFF),
                            (math.sin(t * math.pi * 2) + 1) / 2,
                          )!
                          .withValues(alpha: intensity),
                      blurRadius: widget.size * .34,
                      spreadRadius: widget.size * .03,
                    ),
                  ],
                ),
              ),
              if (widget.state == OtyaBrandState.thinking)
                Transform.rotate(
                  angle: t * math.pi * 2,
                  child: SizedBox(
                    width: widget.size * 1.08,
                    height: widget.size * 1.08,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: widget.size * .09,
                        height: widget.size * .09,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF31E9FF), Color(0xFFFF8A00)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              child!,
            ],
          ),
        );
      },
    );
  }
}
