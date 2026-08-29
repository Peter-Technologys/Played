import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_dimensions.dart';
import '../../shared/widgets/otya_logo.dart';

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      icon: Icons.play_circle_outline_rounded,
      title: 'Your media, without the clutter',
      body:
          'OTYA keeps local video and music at the center. No account or internet connection is required to play files already on your device.',
      points: [
        'Video and Music stay easy to find',
        'Playback continues when online services are unavailable',
        'One compact Video · Music · Me navigation',
      ],
    ),
    _OnboardingPage(
      icon: Icons.grid_view_rounded,
      title: 'Useful tools have a clear home',
      body:
          'Open Me for Transfer, Files, Private, Converter, Playlists, History, Tools, Personalize and Storage—without crowding the main player.',
      points: [
        'Transfer works directly on local Wi-Fi or hotspot',
        'Downloads appear naturally in your media library',
        'Search spans media, folders, artists, albums and playlists',
      ],
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      title: 'You stay in control',
      body:
          'OTYA asks Android only for permissions needed by the feature you use. Private media stays in app-private storage, while Cloudflare and Firebase remain optional for online services.',
      points: [
        'Media access is explained before Android asks',
        'Local playback never depends on sign-in or AI',
        'Settings can review permissions and rescan later',
      ],
    ),
  ];

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
    if (_page == _pages.length - 1) {
      await _finish();
      return;
    }
    await _controller.nextPage(
      duration: AppDimensions.motionEmphasized,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
              child: Row(
                children: [
                  const OtyaLogo(
                    fontSize: 21,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => _PageContent(
                  page: _pages[index],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: AppDimensions.motionStandard,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: index == _page ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index == _page
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _next,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _page == _pages.length - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                      label: Text(
                        _page == _pages.length - 1
                            ? 'Start using OTYA'
                            : 'Continue',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can change permissions and online features later in Settings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXLarge,
                      ),
                    ),
                    child: Icon(page.icon, size: 34, color: scheme.primary),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    page.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.8,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    page.body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  ...page.points.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: .10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              point,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> points;
}
