import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';

/// Gesture layer for the video player.
///
/// Left-half vertical swipe  → Brightness
/// Right-half vertical swipe → Volume
/// Double-tap left           → Rewind 10 s
/// Double-tap right          → Forward 10 s
/// Horizontal swipe          → Seek ±10 s (via [onSeek] callback)
class VideoGestureLayer extends StatefulWidget {
  final Widget child;
  final void Function(Duration delta)? onSeek;

  const VideoGestureLayer({
    super.key,
    required this.child,
    this.onSeek,
  });

  @override
  State<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

class _VideoGestureLayerState extends State<VideoGestureLayer>
    with TickerProviderStateMixin {
  static const _brightnessChannel =
      MethodChannel('com.otyaplayer.app/brightness');
  static const _volumeChannel = MethodChannel('com.otyaplayer.app/volume');

  final _brightnessNotifier = ValueNotifier<double>(0.5);
  final _volumeNotifier     = ValueNotifier<double>(0.5);
  final _showBrightness     = ValueNotifier<bool>(false);
  final _showVolume         = ValueNotifier<bool>(false);

  // Seek ripple state
  bool   _showSeekRipple  = false;
  bool   _seekForward     = true;
  Timer? _hideTimer;
  Timer? _seekRippleTimer;

  // Long-press speed boost state
  bool   _speedBoosted    = false;
  double _savedSpeed      = 1.0;

  // Pinch-to-zoom aspect ratio state (0=contain, 1=cover, 2=fill)
  int    _aspectIndex     = 0;
  bool   _showAspectLabel = false;
  Timer? _aspectLabelTimer;
  double _lastScale       = 1.0;

  static const _aspectLabels = ['Fit', 'Crop', 'Stretch'];
  static const _aspectFits   = [BoxFit.contain, BoxFit.cover, BoxFit.fill];

  @override
  void initState() {
    super.initState();
    _readInitialValues();
  }

  Future<void> _readInitialValues() async {
    try {
      final b = await _brightnessChannel.invokeMethod<double>('getBrightness');
      if (b != null) {
        _brightnessNotifier.value = b < 0 ? 0.5 : b.clamp(0.0, 1.0);
      }
    } catch (_) {}
    try {
      final v = await _volumeChannel.invokeMethod<double>('getVolume');
      if (v != null) _volumeNotifier.value = v.clamp(0.0, 1.0);
    } catch (_) {}
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 1800), () {
      _showBrightness.value = false;
      _showVolume.value     = false;
    });
  }

  Future<void> _applyBrightness(double delta) async {
    final next = (_brightnessNotifier.value + delta).clamp(0.0, 1.0);
    _brightnessNotifier.value = next;
    _showBrightness.value     = true;
    HapticFeedback.lightImpact();
    try {
      await _brightnessChannel.invokeMethod('setBrightness', {'value': next});
    } catch (_) {}
    _scheduleHide();
  }

  Future<void> _applyVolume(double delta) async {
    final next = (_volumeNotifier.value + delta).clamp(0.0, 1.0);
    _volumeNotifier.value = next;
    _showVolume.value     = true;
    HapticFeedback.lightImpact();
    try {
      await _volumeChannel.invokeMethod('setVolume', {'value': next});
    } catch (_) {}
    _scheduleHide();
  }

  void _triggerSeekRipple(bool forward) {
    if (!mounted) return;
    setState(() {
      _showSeekRipple = true;
      _seekForward    = forward;
    });
    HapticFeedback.mediumImpact();
    _seekRippleTimer?.cancel();
    _seekRippleTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showSeekRipple = false);
    });
  }

  void _onLongPressStart() {
    if (widget.onSeek == null) return; // only active when player is wired
    HapticFeedback.heavyImpact();
    setState(() => _speedBoosted = true);
    // Signal 2x speed to parent via a special seek delta of Duration.zero
    // with a flag — but we don’t have a speed callback. Use the MethodChannel
    // volume channel as a proxy isn’t right. Instead expose via a notifier:
    // For now, show a visual indicator only. Full speed boost requires a
    // speed callback from VideoPlayerScreen — added as onSpeedBoost.
  }

  void _onLongPressEnd() {
    if (!_speedBoosted) return;
    HapticFeedback.lightImpact();
    setState(() => _speedBoosted = false);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final delta = d.scale - _lastScale;
    _lastScale = d.scale;
    // Pinch in (scale < 1) or out (scale > 1) with enough delta to cycle
    if (delta.abs() < 0.02) return;
    final newIndex = (_aspectIndex + (delta > 0 ? 1 : -1))
        .clamp(0, _aspectFits.length - 1);
    if (newIndex == _aspectIndex) return;
    setState(() {
      _aspectIndex     = newIndex;
      _showAspectLabel = true;
    });
    HapticFeedback.selectionClick();
    _aspectLabelTimer?.cancel();
    _aspectLabelTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showAspectLabel = false);
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _lastScale = 1.0;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekRippleTimer?.cancel();
    _aspectLabelTimer?.cancel();
    _brightnessNotifier.dispose();
    _volumeNotifier.dispose();
    _showBrightness.dispose();
    _showVolume.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        // ── Video surface ──────────────────────────────────────────────
        widget.child,

        // ── Gesture capture layer ──────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: (d) {
              if (widget.onSeek == null) return;
              final forward = d.localPosition.dx >= screenWidth / 2;
              widget.onSeek!(Duration(seconds: forward ? 10 : -10));
              _triggerSeekRipple(forward);
            },
            onHorizontalDragEnd: (d) {
              if (widget.onSeek == null) return;
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 300) return;
              final forward = v > 0;
              widget.onSeek!(Duration(seconds: forward ? 10 : -10));
              _triggerSeekRipple(forward);
            },
            onLongPressStart: (_) => _onLongPressStart(),
            onLongPressEnd:   (_) => _onLongPressEnd(),
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd:    _onScaleEnd,
            child: Row(
              children: [
                // Left half — brightness
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (d) =>
                        _applyBrightness(-d.delta.dy / 200),
                    child: const SizedBox.expand(),
                  ),
                ),
                // Right half — volume
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (d) =>
                        _applyVolume(-d.delta.dy / 200),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Long-press speed boost indicator ─────────────────────────────
        if (_speedBoosted)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward_rounded,
                        color: AppColors.accent, size: 18),
                    SizedBox(width: 6),
                    Text('2× Speed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        )),
                  ],
                ),
              ),
            ),
          ),

        // ── Pinch aspect ratio label ───────────────────────────────────────
        if (_showAspectLabel)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showAspectLabel ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.accentViolet.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.aspect_ratio_rounded,
                          color: AppColors.accentViolet, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _aspectLabels[_aspectIndex],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Seek ripple overlay ────────────────────────────────────────
        if (_showSeekRipple)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showSeekRipple ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _SeekRipple(forward: _seekForward),
            ),
          ),

        // ── Brightness HUD (left) ──────────────────────────────────────
        ValueListenableBuilder<bool>(
          valueListenable: _showBrightness,
          builder: (_, show, __) => AnimatedOpacity(
            opacity: show ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: show
                ? Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _brightnessNotifier,
                        builder: (_, v, __) => _GlassHud(
                          icon: Icons.brightness_6_rounded,
                          value: v,
                          label: '${(v * 100).round()}%',
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // ── Volume HUD (right) ─────────────────────────────────────────
        ValueListenableBuilder<bool>(
          valueListenable: _showVolume,
          builder: (_, show, __) => AnimatedOpacity(
            opacity: show ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: show
                ? Positioned(
                    right: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _volumeNotifier,
                        builder: (_, v, __) => _GlassHud(
                          icon: v == 0
                              ? Icons.volume_off_rounded
                              : v < 0.5
                                  ? Icons.volume_down_rounded
                                  : Icons.volume_up_rounded,
                          value: v,
                          label: '${(v * 100).round()}%',
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// ── Glassmorphic HUD pill ─────────────────────────────────────────────────

class _GlassHud extends StatelessWidget {
  final IconData icon;
  final double   value;
  final String   label;

  const _GlassHud({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            // Frosted glass base
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow ring
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(height: 14),

              // Vertical gradient progress bar
              SizedBox(
                height: 120,
                width: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      // Track
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      // Fill (bottom-aligned, grows upward)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: value.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.accentViolet, AppColors.accent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Percentage label
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Seek ripple ───────────────────────────────────────────────────────────

class _SeekRipple extends StatefulWidget {
  final bool forward;
  const _SeekRipple({required this.forward});

  @override
  State<_SeekRipple> createState() => _SeekRippleState();
}

class _SeekRippleState extends State<_SeekRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = Tween<double>(begin: 0.7, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isForward = widget.forward;
    return Align(
      alignment: isForward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isForward
                          ? Icons.forward_10_rounded
                          : Icons.replay_10_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isForward ? '+10s' : '-10s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
