import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/played_database.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/media_kit_engine.dart';
import '../../../core/services/pip_service.dart';
import '../../../features/settings/settings_provider.dart';

final batterySaverProvider    = StateProvider<bool>((_) => false);
final controlsVisibleProvider = StateProvider<bool>((_) => true);

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  const VideoPlayerScreen({super.key, required this.mediaItem});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  bool _pipSupported   = false;
  bool _pipAutoEnabled = false;
  bool _batterySaver   = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockToLandscape();
    _initPip();
  }

  Future<void> _initPip() async {
    _pipSupported   = await PipService.instance.isPipSupported();
    _pipAutoEnabled = ref.read(settingsProvider).autoPip;
    await PipService.instance.setVideoPlaying(playing: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _pipAutoEnabled && _pipSupported) {
      PipService.instance.enterPip();
    }
  }

  Future<void> _lockToLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreOrientation() async {
    await PipService.instance.setVideoPlaying(playing: false);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _restoreOrientation();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Duration get _savedPosition =>
      PlayedDatabase.instance.getSeekPosition(widget.mediaItem.id) ??
      Duration.zero;

  @override
  Widget build(BuildContext context) {
    if (_batterySaver) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _BatterySaverOverlay(
          mediaItem: widget.mediaItem,
          onResume: () => setState(() => _batterySaver = false),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MediaKitEngine(
            filePath:      widget.mediaItem.filePath,
            title:         widget.mediaItem.title,
            startPosition: _savedPosition,
            autoPlay:      true,
          ),
          Positioned(
            top: 16, right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => setState(() => _batterySaver = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.battery_saver_rounded, color: AppColors.accentGreen, size: 16),
                      SizedBox(width: 4),
                      Text('Saver', style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatterySaverOverlay extends StatelessWidget {
  final MediaItem    mediaItem;
  final VoidCallback onResume;
  const _BatterySaverOverlay({required this.mediaItem, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.battery_saver_rounded, color: AppColors.accentGreen, size: 64),
            const SizedBox(height: 16),
            const Text('Battery Saver Active',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20,
                    fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            const Text('Audio playing in background.\nVideo rendering paused.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13,
                    height: 1.5, fontFamily: 'Inter')),
            const SizedBox(height: 32),
            _AudioWaveAnimation(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Resume Video',
                  style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioWaveAnimation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Container(
          width: 4, margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleY(begin: 0.2, end: 1.0,
                duration: Duration(milliseconds: 400 + (i * 80)),
                curve: Curves.easeInOut);
      }),
    );
  }
}
