import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/played_logo.dart';

/// 4-screen onboarding shown only on first launch.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_OnboardPage> _pages = [
    _OnboardPage(
      emoji: '\uD83C\uDFAC',
      title: 'My Space',
      subtitle:
          'All your videos and music in one place. Songs, Videos, Folders and Playlists — organised beautifully.',
      color: AppColors.accent,
    ),
    _OnboardPage(
      emoji: '\uD83C\uDFA7',
      title: 'Audio & Video Player',
      subtitle:
          'Shuffle, repeat, EQ, lyrics, sleep timer, car mode, PiP and 2× speed boost.',
      color: AppColors.accentViolet,
    ),
    _OnboardPage(
      emoji: '\uD83D\uDD12',
      title: 'Private Vault',
      subtitle:
          'AES-256 encrypted vault with biometric unlock. Your private media stays private.',
      color: AppColors.accentViolet,
    ),
    _OnboardPage(
      emoji: '\uD83D\uDCF6',
      title: 'Air-Drop',
      subtitle:
          'Share any file with nearby phones using Wi-Fi Direct. Zero internet data used.',
      color: AppColors.accent,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenHeight < 680;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            // Logo at top
            Padding(
              padding: EdgeInsets.only(top: isSmall ? 2 : 8, bottom: isSmall ? 2 : 4),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PlayedLogo(
                    fontSize: 18,
                    letterSpacing: 3,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) =>
                    _PageView(page: _pages[i], index: i, isSmall: isSmall),
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
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? _pages[_page].color
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

            SizedBox(height: isSmall ? 16 : 32),

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
                    borderRadius: BorderRadius.circular(16),
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
                    _page == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 300.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

            SizedBox(height: isSmall ? 16 : 32),

            // Footer
            const PlayedFooter(),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _OnboardPage page;
  final int index;
  final bool isSmall;
  const _PageView({required this.page, required this.index, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final iconSize = (screenHeight * 0.16).clamp(80.0, 120.0);
    final emojiSize = (iconSize * 0.5).clamp(40.0, 60.0);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: isSmall ? 12 : 24),
            // Animated emoji icon
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: page.color.withValues(alpha: 0.1),
                border: Border.all(
                    color: page.color.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: page.color.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(page.emoji,
                    style: TextStyle(fontSize: emojiSize)),
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

            SizedBox(height: isSmall ? 20 : 40),

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

            SizedBox(height: isSmall ? 10 : 16),

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

            SizedBox(height: isSmall ? 12 : 24),
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
  final Color color;
  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
