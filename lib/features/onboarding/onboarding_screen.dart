import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/app_colors.dart';

// ── Design tokens ─────────────────────────────────────────────────────────
const _kGreen = Color(0xFF25D366);
const _kCyan  = Color(0xFF00D2FF);
const _kViolet = Color(0xFF8C52FF);

/// Full-screen onboarding shown on first launch.
/// Exactly 3 slides with rich graphics, skip button, animated dots, and CTA.
class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingOverlay({super.key, required this.onDone});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  bool _dismissing = false;

  late final AnimationController _fadeOut;
  // Equalizer animation for slide 2
  late final AnimationController _eqCtrl;
  // Glow animation for slide 3
  late final AnimationController _glowCtrl;

  static const _ctaLabels = ['NEXT', 'GOT IT', 'GET STARTED'];

  @override
  void initState() {
    super.initState();
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _eqCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeOut.dispose();
    _eqCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    await prefs.setBool('onboarding_done', true);
    await _fadeOut.forward();
    widget.onDone();
  }

  void _next() {
    if (_page < 2) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_fadeOut),
      child: Material(
        color: const Color(0xFF0F111A),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top skip button ──────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF1B1E2B),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Color(0xFF8C94A8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Page content ─────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _Slide1(),
                    _Slide2(eqCtrl: _eqCtrl),
                    _Slide3(glowCtrl: _glowCtrl),
                  ],
                ),
              ),

              // ── Animated page dots ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isActive = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? _kGreen : const Color(0xFF2A2F45),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: _kGreen.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // ── CTA button ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: _next,
                  child: RepaintBoundary(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _kGreen.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _ctaLabels[_page],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Slide 1 — All Video Formats ───────────────────────────────────────────

class _Slide1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic: central mp4 card + 4 floating format badges
          RepaintBoundary(
            child: SizedBox(
              width: 220,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Central rotated card
                  Transform.rotate(
                    angle: -0.15,
                    child: Container(
                      width: 110,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1E2B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _kGreen.withValues(alpha: 0.6), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _kGreen.withValues(alpha: 0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'mp4',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _kGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Floating badges
                  _FormatBadge(label: 'mov', top: 10, left: 10),
                  _FormatBadge(label: 'mkv', top: 10, right: 10),
                  _FormatBadge(label: 'webm', bottom: 10, left: 10),
                  _FormatBadge(label: '3gp', bottom: 10, right: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to OTYA Player',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Popular video player supports all kinds of formats',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF8C94A8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String label;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  const _FormatBadge({
    required this.label,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E2B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kCyan.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: _kCyan.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _kCyan,
          ),
        ),
      ),
    );
  }
}

// ── Slide 2 — Equalizer & Audio ───────────────────────────────────────────

class _Slide2 extends StatelessWidget {
  final AnimationController eqCtrl;
  const _Slide2({required this.eqCtrl});

  @override
  Widget build(BuildContext context) {
    // 5 bar height tweens with different ranges
    final bars = [
      Tween<double>(begin: 20, end: 60).animate(
          CurvedAnimation(parent: eqCtrl, curve: const Interval(0.0, 1.0))),
      Tween<double>(begin: 40, end: 80).animate(
          CurvedAnimation(parent: eqCtrl, curve: const Interval(0.1, 0.9))),
      Tween<double>(begin: 60, end: 30).animate(
          CurvedAnimation(parent: eqCtrl, curve: const Interval(0.2, 0.8))),
      Tween<double>(begin: 30, end: 70).animate(
          CurvedAnimation(parent: eqCtrl, curve: const Interval(0.0, 0.7))),
      Tween<double>(begin: 50, end: 25).animate(
          CurvedAnimation(parent: eqCtrl, curve: const Interval(0.3, 1.0))),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Phone frame with equalizer
          RepaintBoundary(
            child: Container(
              width: 180,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF2A2F45), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _kViolet.withValues(alpha: 0.2),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Equalizer bars
                  AnimatedBuilder(
                    animation: eqCtrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(5, (i) {
                          return Container(
                            width: 14,
                            height: bars[i].value,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kCyan, _kViolet],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Transport controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.skip_previous_rounded,
                          color: Color(0xFF8C94A8), size: 22),
                      SizedBox(width: 12),
                      Icon(Icons.play_circle_filled_rounded,
                          color: _kCyan, size: 36),
                      SizedBox(width: 12),
                      Icon(Icons.skip_next_rounded,
                          color: Color(0xFF8C94A8), size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Floating music notes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      Text('♪', style: TextStyle(color: _kCyan, fontSize: 16)),
                      Text('♫', style: TextStyle(color: _kViolet, fontSize: 20)),
                      Text('♪', style: TextStyle(color: _kCyan, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Start Your New Trip!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enjoy the amazing experience of music player',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF8C94A8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide 3 — Private Vault ───────────────────────────────────────────────

class _Slide3 extends StatelessWidget {
  final AnimationController glowCtrl;
  const _Slide3({required this.glowCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lock icon with animated glow ring + shield icons
          RepaintBoundary(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated glow ring
                  AnimatedBuilder(
                    animation: glowCtrl,
                    builder: (_, __) {
                      final size = 130 + glowCtrl.value * 20;
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color.lerp(
                              _kCyan.withValues(alpha: 0.4),
                              _kViolet.withValues(alpha: 0.6),
                              glowCtrl.value,
                            )!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.lerp(
                                _kCyan.withValues(alpha: 0.2),
                                _kViolet.withValues(alpha: 0.3),
                                glowCtrl.value,
                              )!,
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Central lock icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1E2B),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _kCyan.withValues(alpha: 0.4), width: 2),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: _kCyan,
                      size: 40,
                    ),
                  ),
                  // Shield icons around
                  const Positioned(
                    top: 20,
                    left: 20,
                    child: Icon(Icons.shield_rounded,
                        color: _kViolet, size: 22),
                  ),
                  const Positioned(
                    top: 20,
                    right: 20,
                    child: Icon(Icons.shield_rounded,
                        color: _kCyan, size: 18),
                  ),
                  const Positioned(
                    bottom: 20,
                    left: 20,
                    child: Icon(Icons.shield_rounded,
                        color: _kCyan, size: 18),
                  ),
                  const Positioned(
                    bottom: 20,
                    right: 20,
                    child: Icon(Icons.shield_rounded,
                        color: _kViolet, size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Private Vault & Transfer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'AES-256 encrypted storage and data-free Wi-Fi Direct file transfer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF8C94A8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Keep old class name as alias so nothing else breaks
typedef OnboardingScreen = OnboardingOverlay;
