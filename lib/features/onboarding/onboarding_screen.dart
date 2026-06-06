import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';/// 3-screen onboarding shown only on first launch.
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
          'All your videos and music in one place. Smart shelves auto-sort your Cinema films and DJ mixes.',
      color: AppColors.accent,
    ),
    _OnboardPage(
      emoji: '\uD83D\uDCF6',
      title: 'Air-Drop',
      subtitle:
          'Share any file with nearby phones using Wi-Fi Direct and Bluetooth. Zero internet data used.',
      color: AppColors.accentViolet,
    ),
    _OnboardPage(
      emoji: '\uD83C\uDFA4',
      title: 'The Studio',
      subtitle:
          'Split any song into vocals and instrumental. Practice karaoke or create DJ drops offline.',
      color: AppColors.accent,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text('Skip',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'SpaceGrotesk')),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) =>
                    _PageView(page: _pages[i], index: i),
              ),
            ),

            // Dots
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
            ),

            const SizedBox(height: 32),

            // Next / Get Started
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _next,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _pages[_page].color,
                        AppColors.accentViolet,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _pages[_page].color.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _page == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _OnboardPage page;
  final int index;
  const _PageView({required this.page, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji illustration
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withOpacity(0.1),
              border: Border.all(
                  color: page.color.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(page.emoji,
                  style: const TextStyle(fontSize: 64)),
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

          const SizedBox(height: 40),

          Text(page.title,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: page.color,
                fontFamily: 'SpaceGrotesk',
              ))
              .animate()
              .fadeIn(duration: 400.ms, delay: 150.ms)
              .slideY(begin: 0.1),

          const SizedBox(height: 16),

          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
              fontFamily: 'SpaceGrotesk',
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 250.ms)
              .slideY(begin: 0.1),
        ],
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
