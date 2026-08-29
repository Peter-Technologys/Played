import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/otya_logo.dart';

final Future<Uint8List?> _ownerPortraitBytes = _loadOwnerPortrait();

Future<Uint8List?> _loadOwnerPortrait() async {
  try {
    final encoded =
        await rootBundle.loadString('assets/onboarding/owner_photo.b64');
    final normalized = encoded.replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return null;
    return base64Decode(normalized);
  } catch (_) {
    return null;
  }
}

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  bool _busy = false;

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
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720 || size.width < 360;

    return Material(
      color: const Color(0xFF050611),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  _Hero(compact: compact),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 22,
                      8,
                      compact ? 16 : 22,
                      20,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Welcome to',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontSize: 28,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const _GradientWordmark(),
                        const SizedBox(height: 2),
                        const Text(
                          'PLAYER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF4F4F7),
                            fontFamily: 'Inter',
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your media. Your way. Offline and private.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB8B8C6),
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 20),
                        const Row(
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.music_note_rounded,
                                title: 'Music',
                                subtitle: 'Your tracks',
                                accent: Color(0xFFFF30D1),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.smart_display_rounded,
                                title: 'Video',
                                subtitle: 'Your videos',
                                accent: Color(0xFF3D79FF),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.swap_horiz_rounded,
                                title: 'Transfer',
                                subtitle: 'Local & fast',
                                accent: Color(0xFFFF9D21),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.lock_rounded,
                                title: 'Private',
                                subtitle: 'Keep it yours',
                                accent: Color(0xFF41E57A),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 16 : 22),
                        _GradientContinueButton(
                          busy: _busy,
                          onPressed: _busy ? null : _finish,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Android will ask for media and notification permissions only when they are needed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF77798A),
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 300.0 : 390.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-.7, -.25),
                radius: 1.2,
                colors: [Color(0x442A5CFF), Color(0x00050611)],
              ),
            ),
          ),
          Positioned(
            right: -80,
            top: 70,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0x0014B9FF),
                    Color(0xFF14B9FF),
                    Color(0xFF8C2DFF),
                    Color(0xFFFF1DC8),
                    Color(0xFFFF891E),
                    Color(0x0014B9FF),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 208,
                  height: 208,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF050611),
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _OwnerPortrait()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .45, .78, 1],
                colors: [
                  Color(0x26050611),
                  Color(0x00050611),
                  Color(0xB8050611),
                  Color(0xFF050611),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 18,
            right: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const OtyaMark(size: 54),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'OTYA',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'PLAYER',
                      style: TextStyle(
                        color: Color(0xFFD8D8E1),
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 5.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerPortrait extends StatelessWidget {
  const _OwnerPortrait();

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: _ownerPortraitBytes,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -.12),
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            );
          }
          return Image.asset(
            'assets/onboarding/welcome.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFF050611),
            ),
          );
        },
      );
}

class _GradientWordmark extends StatelessWidget {
  const _GradientWordmark();

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFF06C8FF),
            Color(0xFF405CFF),
            Color(0xFF9B28FF),
            Color(0xFFFF1FC7),
            Color(0xFFFF8E1E),
            Color(0xFFFFD21E),
          ],
        ).createShader(bounds),
        child: const Text(
          'OTYA',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 68,
            height: .92,
            fontWeight: FontWeight.w900,
            letterSpacing: -3,
          ),
        ),
      );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xA90B0D1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: .52)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .08),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: accent),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9B9DAD),
                fontFamily: 'Inter',
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      );
}

class _GradientContinueButton extends StatelessWidget {
  const _GradientContinueButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Continue to OTYA',
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00C7FF),
                  Color(0xFF315CFF),
                  Color(0xFF8D2BFF),
                  Color(0xFFFF1CC9),
                  Color(0xFFFF8B1B),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55315CFF),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 25,
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
