import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/media_item.dart';

enum AspectMode { fit, fill, ratio169, ratio43 }

class PlayerControls extends StatefulWidget {
  final VlcPlayerController controller;
  final MediaItem mediaItem;
  final VoidCallback onBack;
  final ValueChanged<AspectMode>? onAspectChange;
  final VoidCallback? onPip;
  final VoidCallback? onLockScreen;

  const PlayerControls({
    super.key,
    required this.controller,
    required this.mediaItem,
    required this.onBack,
    this.onAspectChange,
    this.onPip,
    this.onLockScreen,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  AspectMode _aspectMode = AspectMode.fit;
  bool _subtitlesOn = false;
  double _speed = 1.0;
  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

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

  void _cycleSpeed() {
    final idx = _speeds.indexOf(_speed);
    setState(() => _speed = _speeds[(idx + 1) % _speeds.length]);
    widget.controller.setPlaybackSpeed(_speed);
    HapticFeedback.selectionClick();
  }

  void _cycleAspect() {
    final next = AspectMode.values[
        (_aspectMode.index + 1) % AspectMode.values.length];
    setState(() => _aspectMode = next);
    widget.onAspectChange?.call(next);
    HapticFeedback.selectionClick();
  }

  void _toggleSubtitles() {
    setState(() => _subtitlesOn = !_subtitlesOn);
    // Track index 0 = first subtitle track; -1 = disabled.
    // Using 1 was wrong — VLC track indices start at 0.
    widget.controller.setSpuTrack(_subtitlesOn ? 0 : -1);
    HapticFeedback.selectionClick();
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            _VideoOption(
              icon: Icons.subtitles_rounded,
              label: 'Subtitles',
              trailing: Switch(
                value: _subtitlesOn,
                onChanged: (_) { Navigator.pop(context); _toggleSubtitles(); },
                activeThumbColor: AppColors.accent,
              ),
            ),
            _VideoOption(
              icon: Icons.aspect_ratio_rounded,
              label: 'Aspect Ratio',
              trailing: Text(_aspectLabel(_aspectMode),
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); _cycleAspect(); },
            ),
            _VideoOption(
              icon: Icons.speed_rounded,
              label: 'Playback Speed',
              trailing: Text('${_speed}x',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); _cycleSpeed(); },
            ),
            _VideoOption(
              icon: Icons.audiotrack_rounded,
              label: 'Audio Track',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38, size: 18),
              onTap: () => Navigator.pop(context),
            ),
            _VideoOption(
              icon: Icons.picture_in_picture_alt_rounded,
              label: 'Picture in Picture',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38, size: 18),
              onTap: () { Navigator.pop(context); widget.onPip?.call(); },
            ),
            _VideoOption(
              icon: Icons.lock_rounded,
              label: 'Lock Screen',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38, size: 18),
              onTap: () { Navigator.pop(context); widget.onLockScreen?.call(); },
            ),
          ],
        ),
      ),
    );
  }

  String _aspectLabel(AspectMode m) => switch (m) {
    AspectMode.fit      => 'Fit',
    AspectMode.fill     => 'Fill',
    AspectMode.ratio169 => '16:9',
    AspectMode.ratio43  => '4:3',
  };

  @override
  Widget build(BuildContext context) {
    final value     = widget.controller.value;
    final position  = value.position;
    final duration  = value.duration;
    final isPlaying = value.isPlaying;
    final progress  = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent, Colors.black87],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: Column(
        children: [

          // ── Top bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: widget.onBack,
                ),
                Expanded(
                  child: Text(widget.mediaItem.title,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SpaceGrotesk',
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                _TopBtn(
                  icon: _subtitlesOn
                      ? Icons.subtitles_rounded
                      : Icons.subtitles_off_rounded,
                  active: _subtitlesOn,
                  onTap: _toggleSubtitles,
                ),
                _TopBtn(
                  icon: Icons.aspect_ratio_rounded,
                  label: _aspectLabel(_aspectMode),
                  onTap: _cycleAspect,
                ),
                _TopBtn(
                  icon: Icons.speed_rounded,
                  label: '${_speed}x',
                  onTap: _cycleSpeed,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white70, size: 22),
                  onPressed: () => _showMoreOptions(context),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Center transport ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Btn(icon: Icons.skip_previous_rounded, size: 28, onTap: () {}),
              const SizedBox(width: 16),
              _Btn(
                icon: Icons.replay_10_rounded, size: 32,
                onTap: () {
                  if (duration == Duration.zero) return;
                  final target = position - const Duration(seconds: 10);
                  widget.controller.seekTo(
                      target < Duration.zero ? Duration.zero : target);
                },
              ),
              const SizedBox(width: 20),
              _Btn(
                icon: isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 60, color: AppColors.accent,
                onTap: () => isPlaying
                    ? widget.controller.pause()
                    : widget.controller.play(),
              ),
              const SizedBox(width: 20),
              _Btn(
                icon: Icons.forward_10_rounded, size: 32,
                onTap: () {
                  if (duration == Duration.zero) return;
                  final target = position + const Duration(seconds: 10);
                  widget.controller.seekTo(
                      target > duration ? duration : target);
                },
              ),
              const SizedBox(width: 16),
              _Btn(icon: Icons.skip_next_rounded, size: 28, onTap: () {}),
            ],
          ),

          const SizedBox(height: 20),

          // ── Seek bar + time ────────────────────────────────
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
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) => widget.controller.seekTo(Duration(
                        milliseconds:
                            (v * duration.inMilliseconds).toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      GestureDetector(
                        onTap: widget.onPip,
                        child: const Icon(
                            Icons.picture_in_picture_alt_rounded,
                            color: Colors.white54, size: 18),
                      ),
                      Text(_fmt(duration),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
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

// ── Top bar button ─────────────────────────────────────────────

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback onTap;
  const _TopBtn(
      {required this.icon, this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: label != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: active ? AppColors.accent : Colors.white24),
                ),
                child: Text(label!,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: active ? AppColors.accent : Colors.white70,
                      fontFamily: 'SpaceGrotesk',
                    )))
            : Icon(icon,
                color: active ? AppColors.accent : Colors.white70, size: 20),
      ),
    );
  }
}

// ── Transport button ───────────────────────────────────────────

class _Btn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;
  const _Btn(
      {required this.icon, required this.size,
       this.color = Colors.white, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: size),
    );
  }
}

// ── More options tile ──────────────────────────────────────────

class _VideoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  const _VideoOption(
      {required this.icon, required this.label,
       required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(label,
          style: const TextStyle(
            color: Colors.white, fontSize: 14, fontFamily: 'SpaceGrotesk',
          )),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      dense: true,
    );
  }
}
