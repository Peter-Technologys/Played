// OtyaSwipeToast — brightness/volume swipe indicator for OTYA Player.
// Extracted and rebranded from Updates-mavplayer/lib/style/volume.dart
// (originally FSliderToast by Befovy, MIT licence).
// Changes: renamed, removed `part of fplayer`, OTYA accent colours,
// added percentage label, rounded progress bar.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

enum OtyaSwipeToastType { volume, brightness }

class OtyaSwipeToast extends StatefulWidget {
  final OtyaSwipeToastType type;
  final double             initial;
  final Stream<double>     stream;

  const OtyaSwipeToast({
    super.key,
    required this.type,
    required this.initial,
    required this.stream,
  });

  @override
  State<OtyaSwipeToast> createState() => _OtyaSwipeToastState();
}

class _OtyaSwipeToastState extends State<OtyaSwipeToast> {
  double _value = 0;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    _sub   = widget.stream.listen((v) {
      if (mounted) setState(() => _value = v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  IconData _icon() {
    if (widget.type == OtyaSwipeToastType.volume) {
      if (_value <= 0)  return Icons.volume_off_rounded;
      if (_value < 0.5) return Icons.volume_down_rounded;
      return Icons.volume_up_rounded;
    } else {
      if (_value <= 0)  return Icons.brightness_low_rounded;
      if (_value < 0.5) return Icons.brightness_medium_rounded;
      return Icons.brightness_high_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.35),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(), color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              height: 3,
              child: LinearProgressIndicator(
                value: _value,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_value * 100).toInt()}%',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, fontFamily: 'Inter'),
            ),
          ],
        ),
      ),
    );
  }
}
