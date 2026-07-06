// OtyaVideoPanel — full-featured video player controls for OTYA Player.
// Adapted from Updates-mavplayer/lib/style/panel2.dart (MIT licence).
// All fplayer types removed. Works with any VideoPlayerAdapter.
//
// Features: swipe brightness/volume, horizontal drag seek, long-press 2x,
// double-tap play/pause, speed menu, screen lock, battery + clock,
// custom OtyaSeekBar with buffer track.

import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../widgets/otya_seek_bar.dart';
import '../widgets/otya_swipe_toast.dart';

// ── Adapter interface ────────────────────────────────────────────────────────

abstract class VideoPlayerAdapter {
  bool     get isPlaying;
  bool     get isFullScreen;
  Duration get position;
  Duration get duration;
  Duration get bufferedPosition;
  double   get speed;

  void play();
  void pause();
  void seekTo(Duration position);
  void setSpeed(double speed);
  void setVolume(double volume); // 0.0–1.0
  void enterFullScreen();
  void exitFullScreen();
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}

// ── Speed option ─────────────────────────────────────────────────────────────

class OtyaSpeedOption {
  final String label;
  final double value;
  const OtyaSpeedOption(this.label, this.value);
}

const List<OtyaSpeedOption> kOtyaDefaultSpeeds = [
  OtyaSpeedOption('2.0×', 2.0),
  OtyaSpeedOption('1.5×', 1.5),
  OtyaSpeedOption('1.25×', 1.25),
  OtyaSpeedOption('1.0×', 1.0),
  OtyaSpeedOption('0.75×', 0.75),
  OtyaSpeedOption('0.5×', 0.5),
];

// ── Main panel ───────────────────────────────────────────────────────────────

class OtyaVideoPanel extends StatefulWidget {
  final VideoPlayerAdapter    adapter;
  final String                title;
  final String                subTitle;
  final int                   hideAfterMs;
  final bool                  doubleTapToPlayPause;
  final VoidCallback?         onBack;
  final VoidCallback?         onSettings;
  final List<OtyaSpeedOption> speeds;

  const OtyaVideoPanel({
    super.key,
    required this.adapter,
    this.title               = '',
    this.subTitle            = '',
    this.hideAfterMs         = 4000,
    this.doubleTapToPlayPause = true,
    this.onBack,
    this.onSettings,
    this.speeds = kOtyaDefaultSpeeds,
  });

  @override
  State<OtyaVideoPanel> createState() => _OtyaVideoPanelState();
}

class _OtyaVideoPanelState extends State<OtyaVideoPanel> {
  VideoPlayerAdapter get _a => widget.adapter;

  bool   _hideControls = true;
  bool   _locked       = false;
  bool   _longPressing = false;
  bool   _showSpeedMenu = false;
  double _seekPos      = -1.0;
  double _speed        = 1.0;

  // Swipe
  bool                _dragLeft   = false;
  double              _swipeValue = 0.0;
  bool                _showSwipe  = false;
  OtyaSwipeToastType  _swipeType  = OtyaSwipeToastType.volume;
  final StreamController<double> _swipeStream =
      StreamController<double>.broadcast();

  // Battery
  final Battery _battery = Battery();
  int           _batteryLevel = 100;
  BatteryState  _batteryState = BatteryState.full;
  StreamSubscription<BatteryState>? _batteryStateSub;
  Timer? _batteryTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _a.addListener(_onAdapterChanged);
    _speed = _a.speed;
    _fetchBattery();
    _batteryStateSub = _battery.onBatteryStateChanged
        .listen((s) { if (mounted) setState(() => _batteryState = s); });
    _batteryTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _fetchBattery());
  }

  @override
  void dispose() {
    _a.removeListener(_onAdapterChanged);
    _hideTimer?.cancel();
    _batteryTimer?.cancel();
    _batteryStateSub?.cancel();
    _swipeStream.close();
    super.dispose();
  }

  void _onAdapterChanged() { if (mounted) setState(() {}); }

  Future<void> _fetchBattery() async {
    try {
      final l = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = l);
    } catch (_) {}
  }

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
    _a.isPlaying ? _a.pause() : _a.play();
    HapticFeedback.selectionClick();
  }

  void _onLongPressStart() {
    if (_locked) return;
    _a.setSpeed(2.0);
    setState(() => _longPressing = true);
  }

  void _onLongPressEnd() {
    _a.setSpeed(_speed);
    setState(() => _longPressing = false);
  }

  void _onVerticalDragStart(DragStartDetails d) {
    if (_locked) return;
    final isRight = d.localPosition.dx > MediaQuery.of(context).size.width / 2;
    _dragLeft   = !isRight;
    _swipeType  = isRight ? OtyaSwipeToastType.volume : OtyaSwipeToastType.brightness;
    _swipeValue = isRight ? 0.8 : 0.5;
    _swipeStream.add(_swipeValue);
    setState(() => _showSwipe = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_locked) return;
    final delta = -(d.primaryDelta! / MediaQuery.of(context).size.height);
    _swipeValue = (_swipeValue + delta).clamp(0.0, 1.0);
    _swipeStream.add(_swipeValue);
    if (!_dragLeft) _a.setVolume(_swipeValue);
    setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails _) =>
      setState(() => _showSwipe = false);

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (_locked) return;
    final durMs = _a.duration.inMilliseconds.toDouble();
    if (durMs <= 0) return;
    final cur  = _seekPos > 0 ? _seekPos : _a.position.inMilliseconds.toDouble();
    final next = (cur + d.delta.dx * 300).clamp(0.0, durMs);
    setState(() => _seekPos = next);
    _restartHideTimer();
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_seekPos > 0) _a.seekTo(Duration(milliseconds: _seekPos.toInt()));
    setState(() => _seekPos = -1.0);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _nowTime() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying    = _a.isPlaying;
    final isFullScreen = _a.isFullScreen;
    final position     = _a.position;
    final duration     = _a.duration;
    final durMs        = duration.inMilliseconds.toDouble();
    final safeMax      = durMs.clamp(1.0, double.infinity);
    final curMs        = (_seekPos > 0
        ? _seekPos
        : position.inMilliseconds.toDouble()).clamp(0.0, safeMax);
    final progress     = durMs > 0 ? curMs / durMs : 0.0;
    final bufMs        = _a.bufferedPosition.inMilliseconds.toDouble();
    final bufPct       = durMs > 0 ? (bufMs / durMs).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:                  _onTap,
      onDoubleTap:            _onDoubleTap,
      onLongPressStart:       (_) => _onLongPressStart(),
      onLongPressEnd:         (_) => _onLongPressEnd(),
      onVerticalDragStart:    _onVerticalDragStart,
      onVerticalDragUpdate:   _onVerticalDragUpdate,
      onVerticalDragEnd:      _onVerticalDragEnd,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd:    _onHorizontalDragEnd,
      child: Stack(
        children: [
          // Controls
          AnimatedOpacity(
            opacity:  _hideControls ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: _hideControls,
              child: _locked
                  ? _buildLockedBg()
                  : _buildControls(context, isPlaying, isFullScreen,
                      position, duration, progress, bufPct),
            ),
          ),
          // Lock chip
          if (_locked)
            Positioned(
              left: 16, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _locked = false),
                  child: _OtyaChip(icon: Icons.lock_rounded, label: 'Tap to unlock'),
                ),
              ),
            ),
          // 2× speed badge
          if (_longPressing)
            Positioned(
              top: 56, left: 0, right: 0,
              child: Center(
                child: _OtyaChip(icon: Icons.fast_forward_rounded, label: '2× Speed'),
              ),
            ),
          // Seek time preview
          if (_seekPos > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${_fmt(Duration(milliseconds: _seekPos.toInt()))} / ${_fmt(duration)}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                ),
              ),
            ),
          // Swipe toast
          if (_showSwipe)
            OtyaSwipeToast(
                type: _swipeType, initial: _swipeValue, stream: _swipeStream.stream),
        ],
      ),
    );
  }

  Widget _buildLockedBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.black54, Colors.transparent, Colors.black54],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
    ),
  );

  Widget _buildControls(
    BuildContext context, bool isPlaying, bool isFullScreen,
    Duration position, Duration duration, double progress, double bufPct,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.transparent, Colors.black87],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(context, isFullScreen),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _a.isPlaying ? _a.pause() : _a.play();
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Colors.black45,
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.accent, size: 36,
                  ),
                ),
              ),
            ),
          ),
          if (_showSpeedMenu) _buildSpeedMenu(),
          _buildBottomBar(context, isPlaying, isFullScreen,
              position, duration, progress, bufPct),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isFullScreen) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: widget.onBack ??
                () => isFullScreen ? _a.exitFullScreen() : Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.title.isNotEmpty)
                  Text(widget.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if (widget.subTitle.isNotEmpty)
                  Text(widget.subTitle,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11, fontFamily: 'Inter'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isFullScreen) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(_nowTime(),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
            ),
            _buildBattery(),
          ],
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
          if (widget.onSettings != null)
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
              onPressed: widget.onSettings,
            ),
        ],
      ),
    );
  }

  Widget _buildBattery() {
    final charging = _batteryState == BatteryState.charging;
    final icon = charging ? Icons.battery_charging_full_rounded
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

  Widget _buildSpeedMenu() => Align(
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
          final sel = _speed == opt.value;
          return GestureDetector(
            onTap: () {
              _a.setSpeed(opt.value);
              setState(() { _speed = opt.value; _showSpeedMenu = false; });
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(opt.label,
                  style: TextStyle(
                    color: sel ? AppColors.accent : Colors.white70,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13, fontFamily: 'Inter',
                  )),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _buildBottomBar(
    BuildContext context, bool isPlaying, bool isFullScreen,
    Duration position, Duration duration, double progress, double bufPct,
  ) {
    final durMs   = duration.inMilliseconds.toDouble();
    final safeMax = durMs.clamp(1.0, double.infinity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            child: OtyaSeekBar(
              value:       (progress * durMs).clamp(0.0, safeMax),
              bufferValue: (bufPct   * durMs).clamp(0.0, safeMax),
              min: 0, max: safeMax,
              colors: OtyaSeekBarColors.branded(),
              onChanged:   (v) { setState(() => _seekPos = v); _restartHideTimer(); },
              onChangeEnd: (v) {
                _a.seekTo(Duration(milliseconds: v.toInt()));
                setState(() => _seekPos = -1.0);
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 28,
                ),
                onPressed: () => isPlaying ? _a.pause() : _a.play(),
              ),
              Text('${_fmt(position)} / ${_fmt(duration)}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _showSpeedMenu = !_showSpeedMenu);
                  _restartHideTimer();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _showSpeedMenu ? AppColors.accent : Colors.white24),
                  ),
                  child: Text('${_speed}×',
                      style: TextStyle(
                        color: _showSpeedMenu ? AppColors.accent : Colors.white70,
                        fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Inter',
                      )),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white, size: 24,
                ),
                onPressed: () =>
                    isFullScreen ? _a.exitFullScreen() : _a.enterFullScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OtyaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _OtyaChip({required this.icon, required this.label});

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
                  color: Colors.white70, fontSize: 10,
                  height: 1.3, fontFamily: 'Inter')),
        ],
      ),
    );
  }
}
