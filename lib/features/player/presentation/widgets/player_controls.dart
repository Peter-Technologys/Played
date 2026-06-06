import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';

class PlayerControls extends StatefulWidget {
  final VlcPlayerController controller;
  final MediaItem mediaItem;
  final VoidCallback onBack;

  const PlayerControls({
    super.key,
    required this.controller,
    required this.mediaItem,
    required this.onBack,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final position = value.position;
    final duration = value.duration;
    final isPlaying = value.isPlaying;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.mediaItem.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SpaceGrotesk',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                      Icons.picture_in_picture_alt_rounded,
                      color: Colors.white70,
                      size: 20),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Spacer(),
          // Center controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Btn(
                icon: Icons.replay_10_rounded,
                size: 32,
                onTap: () => widget.controller
                    .seekTo(position - const Duration(seconds: 10)),
              ),
              const SizedBox(width: 24),
              _Btn(
                icon: isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 56,
                color: AppColors.accent,
                onTap: () => isPlaying
                    ? widget.controller.pause()
                    : widget.controller.play(),
              ),
              const SizedBox(width: 24),
              _Btn(
                icon: Icons.forward_10_rounded,
                size: 32,
                onTap: () => widget.controller
                    .seekTo(position + const Duration(seconds: 10)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Seek bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.accent,
                    overlayColor:
                        AppColors.accent.withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      final target = Duration(
                        milliseconds:
                            (v * duration.inMilliseconds).toInt(),
                      );
                      widget.controller.seekTo(target);
                    },
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11)),
                      Text(_fmt(duration),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _Btn({
    required this.icon,
    required this.size,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: size),
    );
  }
}
