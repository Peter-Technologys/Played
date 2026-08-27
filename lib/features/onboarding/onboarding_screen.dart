import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/permissions/permission_helper.dart';
import '../../../core/services/notification_service.dart';

/// First-run setup: explain OTYA, request media access contextually, explain
/// Now Playing notifications, then enter the library. Account sign-in is not
/// required because OTYA remains offline-first.
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

  Future<void> _next() async {
    if (_busy) return;
    if (_page == 1 && !_mediaGranted) {
      setState(() => _busy = true);
      final granted = await PermissionHelper.requestMediaPermissions(context: context);
      if (!mounted) return;
      setState(() { _mediaGranted = granted; _busy = false; });
      if (!granted) return;
    }
    if (_page == 2 && !_notificationsGranted) {
      setState(() => _busy = true);
      final granted = await NotificationService.instance.requestPermission();
      if (!mounted) return;
      setState(() { _notificationsGranted = granted; _busy = false; });
      // Recommended rather than blocking: playback still works if declined.
    }
    if (_page < 3) {
      await _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      await _finish();
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
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pages = <_SetupPage>[
      const _SetupPage(icon: Icons.play_circle_fill_rounded, eyebrow: 'OTYA PLAYER', title: 'Your media, ready when you are', body: 'Play music and video offline, keep your queue and resume where you stopped — without making an account first.', bullets: ['Music + video in one library', 'Offline-first playback', 'Your files stay on your device']),
      _SetupPage(icon: Icons.video_library_rounded, eyebrow: 'MEDIA ACCESS', title: _mediaGranted ? 'Media access is ready' : 'Let OTYA find your media', body: _mediaGranted ? 'OTYA can now build your library and show artwork, thumbnails, albums and folders.' : 'Allow access so OTYA can discover songs and videos already on this phone. OTYA does not upload your local files.', bullets: const ['Discover music and videos', 'Build thumbnails and album art', 'Notice new files automatically'], success: _mediaGranted),
      _SetupPage(icon: Icons.notifications_active_rounded, eyebrow: 'NOW PLAYING', title: _notificationsGranted ? 'Playback controls are enabled' : 'Control music outside OTYA', body: 'Notifications let Android show Now Playing controls while the screen is locked or you are using another app.', bullets: const ['Lock-screen play / pause', 'Previous and next track', 'Background playback controls'], success: _notificationsGranted),
      const _SetupPage(icon: Icons.auto_awesome_rounded, eyebrow: 'READY', title: 'Make OTYA yours', body: 'Your library will finish scanning in the background. Artwork and thumbnails appear as OTYA discovers your media.', bullets: ['Search everything quickly', 'Continue listening from your queue', 'Change themes later in Settings']),
    ];
    return Material(
      color: const Color(0xFF090B10),
      child: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 18, 24, 0), child: Row(children: [const Text('OTYA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)), const Spacer(), Text('by PeterSmart Link', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12))])),
          Expanded(child: PageView(controller: _controller, physics: const NeverScrollableScrollPhysics(), onPageChanged: (value) => setState(() => _page = value), children: pages)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => AnimatedContainer(duration: const Duration(milliseconds: 220), width: i == _page ? 24 : 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: i == _page ? AppColors.accent : Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99))))),
          const SizedBox(height: 22),
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), child: SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: _busy ? null : _next, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(_buttonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))))),
        ]),
      ),
    );
  }

  String get _buttonLabel {
    if (_page == 1 && !_mediaGranted) return 'Allow media access';
    if (_page == 2 && !_notificationsGranted) return 'Enable playback controls';
    if (_page == 3) return 'Start using OTYA';
    return 'Continue';
  }
}

class _SetupPage extends StatelessWidget {
  final IconData icon; final String eyebrow; final String title; final String body; final List<String> bullets; final bool success;
  const _SetupPage({required this.icon, required this.eyebrow, required this.title, required this.body, required this.bullets, this.success = false});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 52, 28, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 76, height: 76, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: .08))), child: Icon(success ? Icons.check_rounded : icon, color: success ? Colors.greenAccent : AppColors.accent, size: 36)),
      const SizedBox(height: 34),
      Text(eyebrow, style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 31, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -.8)),
      const SizedBox(height: 16),
      Text(body, style: TextStyle(color: Colors.white.withValues(alpha: .62), fontSize: 15, height: 1.55)),
      const SizedBox(height: 30),
      ...bullets.map((text) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 15, color: Colors.white70)), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)))]))),
    ]),
  );
}
