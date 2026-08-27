import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/permissions/permission_helper.dart';
import '../../../core/services/notification_service.dart';
import '../my_space/data/media_repository.dart';

/// First-run setup: explain OTYA, request media access contextually, build the
/// initial local library, explain Now Playing controls, then enter the app.
/// Account sign-in is intentionally not required because OTYA is offline-first.
class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingOverlay({super.key, required this.onDone});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _busy = false;
  bool _mediaGranted = false;
  bool _notificationsGranted = false;
  bool _scanComplete = false;
  int _mediaCount = 0;

  Future<void> _next() async {
    if (_busy) return;

    if (_page == 1 && !_mediaGranted) {
      setState(() => _busy = true);
      final granted = await PermissionHelper.requestMediaPermissions(context: context);
      if (!mounted) return;
      setState(() {
        _mediaGranted = granted;
        _busy = false;
      });
      if (!granted) return;

      // Warm the repository immediately after permission is granted. This means
      // the first Library frame can use real media instead of showing an empty
      // screen while its first scan starts later.
      await _scanInitialLibrary();
      if (!mounted) return;
    }

    if (_page == 2 && !_notificationsGranted) {
      setState(() => _busy = true);
      final granted = await NotificationService.instance.requestPermission();
      if (!mounted) return;
      setState(() {
        _notificationsGranted = granted;
        _busy = false;
      });
      // Recommended rather than blocking: playback still works if declined.
    }

    if (_page < 3) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _scanInitialLibrary() async {
    if (!_mediaGranted || _scanComplete) return;
    setState(() => _busy = true);
    try {
      final items = await MediaRepository.instance.getAllMedia(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _mediaCount = items.length;
        _scanComplete = true;
      });
    } catch (_) {
      // Do not trap a user in onboarding if a manufacturer-specific MediaStore
      // implementation fails. The normal Library refresh can retry afterwards.
    } finally {
      if (mounted) setState(() => _busy = false);
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readyBody = _scanComplete
        ? (_mediaCount == 0
            ? 'Setup is complete. No media is indexed yet; OTYA will keep watching for new songs and videos.'
            : 'OTYA found $_mediaCount media item${_mediaCount == 1 ? '' : 's'} and your library is ready.')
        : 'Your library will finish scanning in the background. Artwork and thumbnails appear as OTYA discovers your media.';

    final pages = <_SetupPage>[
      const _SetupPage(
        icon: Icons.play_circle_fill_rounded,
        eyebrow: 'OTYA PLAYER',
        title: 'Your media, ready when you are',
        body: 'Play music and video offline, keep your queue and resume where you stopped — without making an account first.',
        bullets: [
          'Music + video in one library',
          'Offline-first playback',
          'Your files stay on your device',
        ],
      ),
      _SetupPage(
        icon: Icons.video_library_rounded,
        eyebrow: 'MEDIA ACCESS',
        title: _mediaGranted ? 'Media access is ready' : 'Let OTYA find your media',
        body: _mediaGranted
            ? (_scanComplete
                ? 'Your first library scan is complete. OTYA will continue noticing new media automatically.'
                : 'OTYA can now build your library and show artwork, thumbnails, albums and folders.')
            : 'Allow access so OTYA can discover songs and videos already on this phone. OTYA does not upload your local files.',
        bullets: const [
          'Discover music and videos',
          'Build thumbnails and album art',
          'Notice new files automatically',
        ],
        success: _mediaGranted,
      ),
      _SetupPage(
        icon: Icons.notifications_active_rounded,
        eyebrow: 'NOW PLAYING',
        title: _notificationsGranted
            ? 'Playback controls are enabled'
            : 'Control music outside OTYA',
        body: 'Notifications let Android show Now Playing controls while the screen is locked or you are using another app.',
        bullets: const [
          'Lock-screen play / pause',
          'Previous and next track',
          'Background playback controls',
        ],
        success: _notificationsGranted,
      ),
      _SetupPage(
        icon: Icons.auto_awesome_rounded,
        eyebrow: 'READY',
        title: 'Make OTYA yours',
        body: readyBody,
        bullets: const [
          'Search everything quickly',
          'Continue listening from your queue',
          'Change appearance later in Settings',
        ],
        success: _scanComplete,
      ),
    ];

    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'OTYA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'by PeterSmart Link',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: i == _page ? 24 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _busy ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
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
                          _buttonLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _buttonLabel {
    if (_page == 1 && !_mediaGranted) return 'Allow media access';
    if (_page == 1 && _mediaGranted && !_scanComplete) return 'Scan my media';
    if (_page == 2 && !_notificationsGranted) return 'Enable playback controls';
    if (_page == 3) return 'Start using OTYA';
    return 'Continue';
  }
}

class _SetupPage extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> bullets;
  final bool success;

  const _SetupPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.bullets,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 52, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Icon(
                success ? Icons.check_rounded : icon,
                color: success ? AppColors.success : AppColors.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 34),
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 31,
                height: 1.08,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .62),
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 30),
            ...bullets.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .055),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
