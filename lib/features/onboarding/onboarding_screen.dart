import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/permissions/permission_helper.dart';
import '../../../core/services/notification_service.dart';
import '../my_space/data/media_repository.dart';

/// First-run setup for the approved OTYA visual system.
/// Permissions are requested only after OTYA explains why they are useful.
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
      // The normal Library refresh can retry manufacturer-specific failures.
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
            ? 'Setup is complete. OTYA will keep watching for music and videos as they appear on this phone.'
            : 'OTYA found $_mediaCount media item${_mediaCount == 1 ? '' : 's'}. Your library is ready.')
        : 'Your library can continue scanning in the background while OTYA prepares artwork and thumbnails.';

    final pages = <_SetupPage>[
      const _SetupPage(
        icon: Icons.play_arrow_rounded,
        eyebrow: 'WELCOME TO OTYA',
        title: 'Your media.\nYour way.',
        body: 'A fast, private player for the music and video already on your phone — built around playback, not clutter.',
        bullets: [
          'Music and video in one library',
          'Offline-first playback',
          'No account required to start',
        ],
      ),
      _SetupPage(
        icon: Icons.video_library_rounded,
        eyebrow: 'YOUR LIBRARY',
        title: _mediaGranted ? 'Library access ready' : 'Find what is already yours',
        body: _mediaGranted
            ? (_scanComplete
                ? 'Your first scan is complete. OTYA will continue noticing new media automatically.'
                : 'OTYA can now build your library with artwork, thumbnails, albums and folders.')
            : 'Allow media access so OTYA can discover local songs and videos. Your media files are not uploaded just to play them.',
        bullets: const [
          'Real album artwork',
          'Video thumbnails',
          'Automatic library updates',
        ],
        success: _mediaGranted,
      ),
      _SetupPage(
        icon: Icons.notifications_active_rounded,
        eyebrow: 'NOW PLAYING',
        title: _notificationsGranted ? 'System controls ready' : 'Keep control everywhere',
        body: 'Enable playback notifications so Android can show OTYA controls on the lock screen and while you use other apps.',
        bullets: const [
          'Lock-screen play and pause',
          'Previous and next track',
          'Headset and background controls',
        ],
        success: _notificationsGranted,
      ),
      _SetupPage(
        icon: Icons.auto_awesome_rounded,
        eyebrow: 'READY',
        title: 'Press play.',
        body: readyBody,
        bullets: const [
          'Search your library quickly',
          'Resume from your queue',
          'Explore tools only when you need them',
        ],
        success: _scanComplete,
      ),
    ];

    return Material(
      color: AppColors.background,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, -0.85),
            radius: 1.15,
            colors: [Color(0x188B5CF6), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 11),
                    const Text(
                      'OTYA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_page + 1} / 4',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 3,
                        margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? AppColors.accent
                              : AppColors.borderSubtle,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                      disabledBackgroundColor: AppColors.surfaceHighlight,
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
        padding: const EdgeInsets.fromLTRB(28, 50, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: success
                      ? AppColors.success.withValues(alpha: .35)
                      : AppColors.accent.withValues(alpha: .28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (success ? AppColors.success : AppColors.accent)
                        .withValues(alpha: .10),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Icon(
                success ? Icons.check_rounded : icon,
                color: success ? AppColors.success : AppColors.accent,
                size: 38,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 34,
                height: 1.03,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              body,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: bullets
                    .map(
                      (text) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: .10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      );
}
