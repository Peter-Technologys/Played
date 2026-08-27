import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingOverlay({super.key, required this.onDone});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  static const _screens = <String>[
    'assets/onboarding/welcome.jpg',
    'assets/onboarding/download.jpg',
    'assets/onboarding/video.jpg',
    'assets/onboarding/organize.jpg',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm the bundled photos before the user starts paging. A failed preload
    // is intentionally non-fatal; Image.asset below still retries normally.
    for (final asset in _screens) {
      precacheImage(AssetImage(asset), context).catchError((_) {});
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLaunch', false);
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
    if (mounted) widget.onDone();
  }

  Future<void> _next() async {
    if (_page == _screens.length - 1) return _finish();
    await _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _photo(String asset) => ColoredBox(
        color: const Color(0xFF02051D),
        child: SizedBox.expand(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Color(0xFF02051D),
              child: Center(
                child: Icon(Icons.image_not_supported_outlined,
                    color: Colors.white54, size: 44),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF02051D),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _screens.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _photo(_screens[i]),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 14),
                  child: TextButton(
                    onPressed: _busy ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black38,
                    ),
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF00C8FF),
                        Color(0xFF5B39FF),
                        Color(0xFFFF19B8),
                      ]),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(color: Color(0x5500C8FF), blurRadius: 22),
                      ],
                    ),
                    child: TextButton(
                      onPressed: _busy ? null : _next,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _page == _screens.length - 1
                                  ? 'Get Started  →'
                                  : 'Continue  →',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
