import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/played_logo.dart';

/// Full-screen overlay shown on first launch, on top of the real dashboard.
/// The user can see the app behind it and dismiss it to start using it.
class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingOverlay({super.key, required this.onDone});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  int _page = 0;
  bool _dismissing = false;
  late final AnimationController _fadeOut;

  static const List<_OnboardPage> _pages = [
    _OnboardPage(
      emoji: '\uD83C\uDFAC',
      title: 'My Space',
      subtitle: 'All your videos and music in one place. Songs, Videos, Folders and Playlists — organised beautifully.',
      color: AppColors.accent,
      hint: 'Your library is loading right behind this screen.',
    ),
    _OnboardPage(
      emoji: '\uD83C\uDFA7',
      title: 'Audio & Video Player',
      subtitle: 'Shuffle, repeat, EQ, lyrics, sleep timer, car mode, PiP and 2× speed boost.',
      color: AppColors.accentViolet,
      hint: 'Tap any song or video in My Space to start playing.',
    ),
    _OnboardPage(
      emoji: '\uD83D\uDD12',
      title: 'Private Vault',
      subtitle: 'AES-256 encrypted vault with biometric unlock. Your private media stays private.',
      color: AppColors.accentViolet,
      hint: 'Long-press any file → Move to Vault.',
    ),
    _OnboardPage(
      emoji: '\uD83D\uDCF6',
      title: 'Air-Drop',
      subtitle: 'Share any file with nearby phones using Wi-Fi Direct. Zero internet data used.',
      color: AppColors.accent,
      hint: 'Tap the Air-Drop tab in the bottom nav bar.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeOut.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);
    await _fadeOut.forward();
    widget.onDone();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenHeight < 680;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_fadeOut),
      child: Material(
        color: Colors.transparent,
        child: Container(
          // Semi-transparent dark overlay so the app is faintly visible behind
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.97),
                AppColors.background.withValues(alpha: 0.99),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top bar: logo + skip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PlayedLogo(
                          fontSize: 16,
                          letterSpacing: 3,
                          borderRadius: 8,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _dismiss,
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, i) =>
                        _PageCard(page: _pages[i], isSmall: isSmall),
                  ),
                ),

                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: i == _page ? 10 : 8,
                      decoration: BoxDecoration(
                        color: i == _page ? _pages[_page].color : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: i == _page
                            ? [
                                BoxShadow(
                                  color: _pages[_page].color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                SizedBox(height: isSmall ? 14 : 24),

                // CTA button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: _next,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_pages[_page].color, AppColors.accentViolet],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_page].color.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _page == _pages.length - 1 ? 'Start Using OTYA Player' : 'Next',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

                SizedBox(height: isSmall ? 14 : 24),
                const PlayedFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageCard extends StatelessWidget {
  final _OnboardPage page;
  final bool isSmall;
  const _PageCard({required this.page, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final iconSize = (screenHeight * 0.15).clamp(72.0, 110.0);
    final emojiSize = (iconSize * 0.48).clamp(36.0, 54.0);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: isSmall ? 16 : 32),

            // Emoji icon
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    page.color.withValues(alpha: 0.15),
                    page.color.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: page.color.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: page.color.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 14,
                  ),
                ],
              ),
              child: Center(
                child: Text(page.emoji, style: TextStyle(fontSize: emojiSize)),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 300.ms),

            SizedBox(height: isSmall ? 20 : 36),

            // Title
            Text(
              page.title,
              style: TextStyle(
                fontSize: isSmall ? 22 : 26,
                fontWeight: FontWeight.w700,
                color: page.color,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 150.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),

            SizedBox(height: isSmall ? 10 : 14),

            // Subtitle
            Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmall ? 13 : 15,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 250.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),

            SizedBox(height: isSmall ? 14 : 20),

            // Contextual hint chip — points to the real feature in the app
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: page.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, color: page.color, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      page.hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: page.color,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 350.ms),

            SizedBox(height: isSmall ? 16 : 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String hint;
  final Color color;
  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.color,
  });
}

// Keep old class name as alias so nothing else breaks
typedef OnboardingScreen = OnboardingOverlay;
