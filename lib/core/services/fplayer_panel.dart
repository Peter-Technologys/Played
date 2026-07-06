// Adapted from Updates-mavplayer/lib/style/panel2.dart
// Changes:
//   - All Chinese UI strings translated to English
//   - Removed fplayer-specific FPlayer / FState / FData types
//   - Replaced with a thin [VideoPlayerAdapter] interface so the panel
//     works with flutter_vlc_player (VlcPlayerController) or any backend
//   - Integrated with AppColors for consistent OTYA Player branding
//   - Removed dead connectivity_plus code (commented out in original)

import 'dart:async';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';

// ── Adapter interface ─────────────────────────────────────────────────────────
// Implement this for VlcPlayerController (or any other backend).

abstract class VideoPlayerAdapter {
  bool get isPlaying;
  bool get isFullScreen;
  Duration get position;
  Duration get duration;
  Duration get bufferedPosition;
  double get speed;

  void play();
  void pause();
  void seekTo(Duration position);
  void setSpeed(double speed);
  void enterFullScreen();
  void exitFullScreen();
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);

  /// Volume 0.0–1.0
  void setVolume(double volume);
}

// ── Speed / resolution data classes ──────────────────────────────────────────

class SpeedOption {
  final String label;
  final double value;
  const SpeedOption(this.label, this.value);
}

const List<SpeedOption> kDefaultSpeeds = [
  SpeedOption('2.0×', 2.0),
  SpeedOption('1.5×', 1.5),
  SpeedOption('1.25×', 1.25),
  SpeedOption('1.0×', 1.0),
  SpeedOption('0.75×', 0.75),
  SpeedOption('0.5×', 0.5),
];

// ── Main panel widget ─────────────────────────────────────────────────────────

class OtyaVideoPanel extends StatefulWidget {
  final VideoPlayerAdapter adapter;
  final String title;
  final String subTitle;
  final int hideAfterMs;
  final bool doubleTapToPlayPause;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final List<SpeedOption> speeds;

  const OtyaVideoPanel({
    super.key,
    required this.adapter,
    this.title = '',
    this.subTitle = '',
    this.hideAfterMs = 4000,
    this.doubleTapToPlayPause = true,
    this.onBack,
    this.onSettings,
    this.speeds = kDefaultSpeeds,
  });

  @override
  State<OtyaVideoPanel> createState() => _OtyaVideoPanelState();
}

class _OtyaVideoPanelState extends State<OtyaVideoPanel> {
  VideoPlayerAdapter get _adapter => widget.adapter;

  // ── UI state ────────────────────────────────────────────────────────────────
  bool _hideControls = true;
  bool _locked = false;
  bool _longPressing = false;
  bool _showSpeedMenu = false;

  // Seek drag
  double _seekPos = -1.0; // -1 means not dragging

  // Swipe gesture
  bool _dragLeft = false;
  double? _swipeVolume;
  double? _swipeBrightness;
  double _swipeIndicatorValue = 0.0;
  bool _showSwipeIndicator = false;

  // Speed
  double _speed = 1.0;

  // Battery
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  StreamSubscription<BatteryState>? _batteryStateSub;
  Timer? _batteryTimer;

  // Controls hide timer
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _adapter.addListener(_onAdapterChanged);
    _speed = _adapter.speed;
    _fetchBattery();
    _batteryStateSub = _battery.onBatteryStateChanged.listen((s) {
      if (mounted) setState(() => _batteryState = s);
    });
    _batteryTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _fetchBattery());
  }

  @override
  void dispose() {
    _adapter.removeListener(_onAdapterChanged);
    _hideTimer?.cancel();
    _batteryTimer?.cancel();
    _batteryStateSub?.cancel();
    super.dispose();
  }

  void _onAdapterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (_) {}
  }

  // ── Controls visibility ──────────────────────────────────────────────────────

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(milliseconds: widget.hideAfterMs), () {
      if (mounted) setState(() { _hideControls = true; _showSpeedMenu = false; });
    });
  }

  void _onTap() {
    if (_locked) return;
    setState(() => _hideControls = !_hideControls);
    if (!_hideControls) _restartHideTimer();
  }

  void _onDoubleTap() {
    if (_locked || !widget.doubleTapToPlayPause) return;
    _adapter.isPlaying ? _adapter.pause() : _adapter.play();
    HapticFeedback.selectionClick();
  }

  // ── Long press 2× speed ──────────────────────────────────────────────────────

  void _onLongPressStart() {
    if (_locked) return;
    _adapter.setSpeed(2.0);
    setState(() => _longPressing = true);
  }

  void _onLongPressEnd() {
    _adapter.setSpeed(_speed);
    setState(() => _longPressing = false);
  }

  // ── Swipe gestures ───────────────────────────────────────────────────────────

  void _onVerticalDragStart(DragStartDetails d) {
    if (_locked) return;
    final isRightSide = d.localPosition.dx > MediaQuery.of(context).size.width / 2;
    _dragLeft = !isRightSide;
    if (isRightSide) {
      // Volume
      _swipeVolume = 0.8; // default; ideally read from system
      _swipeIndicatorValue = _swipeVolume!;
    } else {
      // Brightness
      _swipeBrightness = 0.5;
      _swipeIndicatorValue = _swipeBrightness!;
    }
    setState(() => _showSwipeIndicator = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_locked) return;
    final delta = -(d.primaryDelta! / MediaQuery.of(context).size.height);
    if (!_dragLeft) {
      // Volume
      final v = ((_swipeVolume ?? 0.8) + delta).clamp(0.0, 1.0);
      _swipeVolume = v;
      _adapter.setVolume(v);
      setState(() => _swipeIndicatorValue = v);
    } else {
      // Brightness
      final b = ((_swipeBrightness ?? 0.5) + delta).clamp(0.0, 1.0);
      _swipeBrightness = b;
      // Screen brightness via platform channel (screen_brightness package
      // or direct method channel — kept as no-op here to avoid extra dep)
      setState(() => _swipeIndicatorValue = b);
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    _swipeVolume = null;
    _swipeBrightness = null;
    setState(() => _showSwipeIndicator = false);
  }

  // ── Horizontal drag seek ─────────────────────────────────────────────────────

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (_locked) return;
    final duration = _adapter.duration.inMilliseconds.toDouble();
    if (duration <= 0) return;
    final current = _seekPos > 0
        ? _seekPos
        : _adapter.position.inMilliseconds.toDouble();
    final next = (current + d.delta.dx * 300).clamp(0.0, duration);
    setState(() => _seekPos = next);
    _restartHideTimer();
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_seekPos > 0) {
      _adapter.seekTo(Duration(milliseconds: _seekPos.toInt()));
    }
    setState(() => _seekPos = -1.0);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPlaying   = _adapter.isPlaying;
    final position    = _adapter.position;
    final duration    = _adapter.duration;
    final isFullScreen = _adapter.isFullScreen;
    final durationMs  = duration.inMilliseconds.toDouble();
    final currentMs   = _seekPos > 0
        ? _seekPos
        : position.inMilliseconds.toDouble().clamp(0.0, max(durationMs, 1.0));
    final progress    = durationMs > 0 ? currentMs / durationMs : 0.0;
    final bufferedMs  = _adapter.bufferedPosition.inMilliseconds.toDouble();
    final bufferedPct = durationMs > 0
        ? (bufferedMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onDoubleTap: _onDoubleTap,
      onLongPressStart: (_) => _onLongPressStart(),
      onLongPressEnd: (_) => _onLongPressEnd(),
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        children: [
          // ── Controls overlay ─────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _hideControls ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: _hideControls,
              child: _locked
                  ? _buildLockedOverlay()
                  : _buildFullControls(
                      context, isPlaying, isFullScreen,
                      position, duration, progress, bufferedPct,
                    ),
            ),
          ),

          // ── Lock overlay (always visible when locked) ─────────────────
          if (_locked)
            Positioned(
              left: 16,
              top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _locked = false),
                  child: _ControlChip(
                    icon: Icons.lock_rounded,
                    label: 'Tap to unlock',
                  ),
                ),
              ),
            ),

          // ── 2× speed badge ───────────────────────────────────────────────
          if (_longPressing)
            Positioned(
              top: 56, left: 0, right: 0,
              child: Center(
                child: _ControlChip(
                  icon: Icons.fast_forward_rounded,
                  label: '2× Speed',
                ),
              ),
            ),

          // ── Seek drag time display ────────────────────────────────────────
          if (_seekPos > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_fmt(Duration(milliseconds: _seekPos.toInt()))} / ${_fmt(duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),

          // ── Swipe indicator (brightness / volume) ─────────────────────────
          if (_showSwipeIndicator)
            Positioned(
              left: _dragLeft ? 24 : null,
              right: _dragLeft ? null : 24,
              top: 0, bottom: 0,
              child: Center(
                child: _SwipeIndicator(
                  icon: _dragLeft
                      ? Icons.brightness_6_rounded
                      : Icons.volume_up_rounded,
                  value: _swipeIndicatorValue,
                  color: _dragLeft ? Colors.amber : AppColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Locked overlay ────────────────────────────────────────────────────────

  Widget _buildLockedOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black54, Colors.transparent, Colors.black54],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // ── Full controls ─────────────────────────────────────────────────────────

  Widget _buildFullControls(
    BuildContext context,
    bool isPlaying,
    bool isFullScreen,
    Duration position,
    Duration duration,
    double progress,
    double bufferedPct,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.transparent, Colors.black87],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        children: [
          // ── Top bar ────────────────────────────────────────────────────
          _buildTopBar(context, isFullScreen),

          // ── Center play/pause ──────────────────────────────────────────
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _adapter.isPlaying ? _adapter.pause() : _adapter.play();
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppColors.accent,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),

          // ── Speed menu (shown above bottom bar) ────────────────────────
          if (_showSpeedMenu) _buildSpeedMenu(),

          // ── Bottom bar ─────────────────────────────────────────────────
          _buildBottomBar(
              context, isPlaying, isFullScreen,
              position, duration, progress, bufferedPct),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, bool isFullScreen) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: widget.onBack ??
                () => isFullScreen
                    ? _adapter.exitFullScreen()
                    : Navigator.of(context).pop(),
          ),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.title.isNotEmpty)
                  Text(widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (widget.subTitle.isNotEmpty)
                  Text(widget.subTitle,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11,
                          fontFamily: 'Inter'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Clock
          if (isFullScreen)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _nowTime(),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, fontFamily: 'Inter'),
              ),
            ),
          // Battery
          if (isFullScreen) _buildBattery(),
          // Lock
          IconButton(
            icon: Icon(
              _locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: Colors.white70, size: 20,
            ),
            onPressed: () {
              setState(() => _locked = !_locked);
              if (_locked) _hideTimer?.cancel();
              HapticFeedback.selectionClick();
            },
          ),
          // Settings
          if (widget.onSettings != null)
            IconButton(
              icon: const Icon(Icons.settings_rounded,
                  color: Colors.white70, size: 20),
              onPressed: widget.onSettings,
            ),
        ],
      ),
    );
  }

  String _nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBattery() {
    final isCharging = _batteryState == BatteryState.charging;
    final icon = isCharging
        ? Icons.battery_charging_full_rounded
        : _batteryLevel < 14 ? Icons.battery_1_bar_rounded
        : _batteryLevel < 28 ? Icons.battery_2_bar_rounded
        : _batteryLevel < 42 ? Icons.battery_3_bar_rounded
        : _batteryLevel < 56 ? Icons.battery_4_bar_rounded
        : _batteryLevel < 70 ? Icons.battery_5_bar_rounded
        : _batteryLevel < 84 ? Icons.battery_6_bar_rounded
        : Icons.battery_full_rounded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$_batteryLevel%',
            style: const TextStyle(
                color: Colors.white70, fontSize: 10, fontFamily: 'Inter')),
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Speed menu ────────────────────────────────────────────────────────────

  Widget _buildSpeedMenu() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(right: 16, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.speeds.map((opt) {
            final selected = _speed == opt.value;
            return GestureDetector(
              onTap: () {
                _adapter.setSpeed(opt.value);
                setState(() { _speed = opt.value; _showSpeedMenu = false; });
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  opt.label,
                  style: TextStyle(
                    color: selected ? AppColors.accent : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(
    BuildContext context,
    bool isPlaying,
    bool isFullScreen,
    Duration position,
    Duration duration,
    double progress,
    double bufferedPct,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
          _buildSeekBar(progress, bufferedPct, duration),
          const SizedBox(height: 4),
          // Transport row
          Row(
            children: [
              // Play/pause
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 28,
                ),
                onPressed: () =>
                    isPlaying ? _adapter.pause() : _adapter.play(),
              ),
              // Time
              Text(
                '${_fmt(position)} / ${_fmt(duration)}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, fontFamily: 'Inter'),
              ),
              const Spacer(),
              // Speed
              GestureDetector(
                onTap: () {
                  setState(() => _showSpeedMenu = !_showSpeedMenu);
                  _restartHideTimer();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _showSpeedMenu
                            ? AppColors.accent
                            : Colors.white24),
                  ),
                  child: Text(
                    '${_speed}×',
                    style: TextStyle(
                      color: _showSpeedMenu
                          ? AppColors.accent
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Fullscreen
              IconButton(
                icon: Icon(
                  isFullScreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white, size: 24,
                ),
                onPressed: () => isFullScreen
                    ? _adapter.exitFullScreen()
                    : _adapter.enterFullScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar(double progress, double bufferedPct, Duration duration) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Colors.white24,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        secondaryActiveTrackColor: Colors.white38,
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        secondaryTrackValue: bufferedPct.clamp(0.0, 1.0),
        onChanged: (v) {
          setState(() => _seekPos = v * duration.inMilliseconds.toDouble());
          _restartHideTimer();
        },
        onChangeEnd: (v) {
          _adapter.seekTo(
              Duration(milliseconds: (v * duration.inMilliseconds).toInt()));
          setState(() => _seekPos = -1.0);
        },
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _ControlChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ControlChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  height: 1.3,
                  fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

class _SwipeIndicator extends StatelessWidget {
  final IconData icon;
  final double value;
  final Color color;
  const _SwipeIndicator(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          width: 4,
          child: RotatedBox(
            quarterTurns: -1,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(value * 100).toInt()}%',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'Inter')),
      ],
    );
  }
}
