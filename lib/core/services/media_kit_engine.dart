import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/modern_neon_container.dart';

// ── Track models ─────────────────────────────────────────────────────────────────────

class _TrackOption {
  final String id;
  final String label;
  const _TrackOption(this.id, this.label);
}

// ── MediaKitEngine ───────────────────────────────────────────────────────────────────

/// Core 2027 MediaKit video engine widget.
///
/// Lifecycle:
///   1. [initState] creates Player + VideoController asynchronously.
///   2. [_openFile] validates the file exists before calling player.open().
///   3. [_buildTrackMenu] reads embedded subtitle + audio tracks from the
///      player’s track list and exposes them via a bottom sheet.
///   4. [dispose] calls player.dispose() to release all native resources.
///
/// Why media_kit instead of flutter_vlc_player:
///   flutter_vlc_player bundles a 30+ MB C++ VLC binary that conflicts with
///   modern Gradle versions and causes CI runner timeouts. media_kit uses
///   platform-native hardware decoders (MediaCodec on Android) with a tiny
///   shared library footprint.
class MediaKitEngine extends StatefulWidget {
  final String   filePath;
  final String   title;
  final Duration startPosition;
  final bool     autoPlay;
  /// Called once the internal [Player] is created and ready.
  /// Use this to wire external controls (seek, play/pause, volume, rate).
  final void Function(Player player)? onPlayerReady;

  const MediaKitEngine({
    super.key,
    required this.filePath,
    this.title        = '',
    this.startPosition = Duration.zero,
    this.autoPlay     = true,
    this.onPlayerReady,
  });

  @override
  State<MediaKitEngine> createState() => _MediaKitEngineState();
}

class _MediaKitEngineState extends State<MediaKitEngine> {
  late final Player          _player;
  late final VideoController _controller;

  bool   _initialized = false;
  bool   _hasError    = false;
  String _errorMsg    = '';

  // Track lists populated after the media opens
  List<_TrackOption> _subtitleTracks = [];
  List<_TrackOption> _audioTracks    = [];
  String?            _activeSubId;
  String?            _activeAudioId;

  // Subscriptions
  StreamSubscription? _trackSub;
  StreamSubscription? _errorSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _player = Player(
        configuration: const PlayerConfiguration(
          // logLevel: MPVLogLevel.warn, // uncomment for debugging
          title: 'OTYA Player',
        ),
      );
      _controller = VideoController(
        _player,
        configuration: const VideoControllerConfiguration(
          // Use hardware decoding on all Android devices.
          // Falls back to software automatically if unsupported.
          enableHardwareAcceleration: true,
        ),
      );

      // Listen for track changes (fires after media opens)
      _trackSub = _player.stream.tracks.listen(_onTracksChanged);

      // Listen for player errors
      _errorSub = _player.stream.error.listen((err) {
        if (mounted && err.isNotEmpty) {
          setState(() { _hasError = true; _errorMsg = err; });
        }
      });

      // Open the file before marking initialized so the Video widget only
      // renders once the player has a valid source ready.
      await _openFile();

      // Notify the parent widget that the player is ready for external control.
      widget.onPlayerReady?.call(_player);

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMsg = e.toString(); });
    }
  }

  Future<void> _openFile() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _hasError = true;
          _errorMsg = 'File not found:\n${widget.filePath}';
        });
        return;
      }

      await _player.open(
        Media(widget.filePath),
        play: false, // seek first, then play
      );

      if (widget.startPosition > Duration.zero) {
        await _player.seek(widget.startPosition);
      }

      if (widget.autoPlay) await _player.play();
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMsg = e.toString(); });
    }
  }

  void _onTracksChanged(Tracks tracks) {
    if (!mounted) return;
    // Build subtitle track list
    final subs = <_TrackOption>[
      const _TrackOption('no', 'Off'),
    ];
    for (final t in tracks.subtitle) {
      final label = t.language?.isNotEmpty == true
          ? t.language!
          : t.title?.isNotEmpty == true
              ? t.title!
              : 'Track ${subs.length}';
      subs.add(_TrackOption(t.id, label));
    }

    // Build audio track list
    final audio = <_TrackOption>[];
    for (final t in tracks.audio) {
      final label = t.language?.isNotEmpty == true
          ? t.language!
          : t.title?.isNotEmpty == true
              ? t.title!
              : 'Track ${audio.length + 1}';
      audio.add(_TrackOption(t.id, label));
    }

    setState(() {
      _subtitleTracks = subs;
      _audioTracks    = audio;
      _activeSubId    ??= 'no';
      _activeAudioId  ??= audio.isNotEmpty ? audio.first.id : null;
    });
  }

  Future<void> _setSubtitleTrack(String id) async {
    try {
      if (id == 'no') {
        await _player.setSubtitleTrack(SubtitleTrack.no());
      } else {
        final track = _player.state.tracks.subtitle
            .firstWhere((t) => t.id == id, orElse: () => SubtitleTrack.no());
        await _player.setSubtitleTrack(track);
      }
      setState(() => _activeSubId = id);
    } catch (e) {
      debugPrint('[MediaKit] setSubtitleTrack error: $e');
    }
  }

  Future<void> _setAudioTrack(String id) async {
    try {
      final track = _player.state.tracks.audio
          .firstWhere((t) => t.id == id, orElse: () => AudioTrack.auto());
      await _player.setAudioTrack(track);
      setState(() => _activeAudioId = id);
    } catch (e) {
      debugPrint('[MediaKit] setAudioTrack error: $e');
    }
  }

  @override
  void dispose() {
    // Cancel subscriptions BEFORE disposing the player so their callbacks
    // cannot fire after the player is torn down (avoids setState-after-dispose).
    _trackSub?.cancel();
    _errorSub?.cancel();
    _trackSub = null;
    _errorSub = null;
    // Dispose releases all native MPV/MediaCodec resources.
    // Must be called to prevent memory leaks on track navigation.
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorState();
    if (!_initialized) return _buildLoadingState();

    return MediaKitGestureWrapper(
      player:     _player,
      controller: _controller,
      title:      widget.title,
      onTracksTap: _subtitleTracks.length > 1 || _audioTracks.length > 1
          ? () => _showTrackMenu(context)
          : null,
    );
  }

  // ── Loading state ───────────────────────────────────────────────────────────────

  Widget _buildLoadingState() => const ColoredBox(
    color: Colors.black,
    child: Center(
      child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
    ),
  );

  // ── Error state ────────────────────────────────────────────────────────────────

  Widget _buildErrorState() => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ModernNeonContainer(
          neonColor: AppColors.error,
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text('Cannot play this file',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, fontFamily: 'Inter',
                  )),
              const SizedBox(height: 8),
              Text(
                _errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary,
                  fontFamily: 'Inter', height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() { _hasError = false; _errorMsg = ''; });
                  _openFile();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontFamily: 'Inter')),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ── Track menu ─────────────────────────────────────────────────────────────────

  void _showTrackMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TrackMenuSheet(
        subtitleTracks: _subtitleTracks,
        audioTracks:    _audioTracks,
        activeSubId:    _activeSubId,
        activeAudioId:  _activeAudioId,
        onSubSelected:  _setSubtitleTrack,
        onAudioSelected: _setAudioTrack,
      ),
    );
  }
}

// ── Track menu sheet ───────────────────────────────────────────────────────────────────

class _TrackMenuSheet extends StatelessWidget {
  final List<_TrackOption> subtitleTracks;
  final List<_TrackOption> audioTracks;
  final String?            activeSubId;
  final String?            activeAudioId;
  final void Function(String) onSubSelected;
  final void Function(String) onAudioSelected;

  const _TrackMenuSheet({
    required this.subtitleTracks,
    required this.audioTracks,
    required this.activeSubId,
    required this.activeAudioId,
    required this.onSubSelected,
    required this.onAudioSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          if (subtitleTracks.length > 1) ...[
            _sectionHeader('Subtitles'),
            ...subtitleTracks.map((t) => _trackTile(
              context, t, activeSubId == t.id,
              AppColors.accent, () => onSubSelected(t.id),
            )),
            const SizedBox(height: 16),
          ],
          if (audioTracks.length > 1) ...[
            _sectionHeader('Audio Track'),
            ...audioTracks.map((t) => _trackTile(
              context, t, activeAudioId == t.id,
              AppColors.accentViolet, () => onAudioSelected(t.id),
            )),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2, fontFamily: 'Inter',
        )),
  );

  Widget _trackTile(
    BuildContext context,
    _TrackOption track,
    bool active,
    Color accent,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: active ? accent : AppColors.textSecondary,
        size: 20,
      ),
      title: Text(track.label,
          style: TextStyle(
            fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active ? accent : AppColors.textPrimary,
            fontFamily: 'Inter',
          )),
      onTap: () { Navigator.of(context).pop(); onTap(); },
    );
  }
}

// ── Gesture wrapper ───────────────────────────────────────────────────────────────────

/// Wraps the Video widget with gesture controls and the neon HUD overlay.
///
/// Gesture map:
///   Double-tap left      → rewind 10 s (via _onDoubleTapDown)
///   Double-tap right     → forward 10 s (via _onDoubleTapDown)
///   Tap                  → toggle transport controls
///
/// Brightness/volume/seek swipe gestures are handled by VideoGestureLayer
/// (the parent widget) which uses real platform channels for brightness and
/// volume. Conflicting handlers have been removed from this wrapper to avoid
/// gesture arena conflicts.
///
/// Performance:
///   RepaintBoundary around the Video widget ensures the video surface
///   never repaints due to HUD changes.
class MediaKitGestureWrapper extends StatefulWidget {
  final Player          player;
  final VideoController controller;
  final String          title;
  final VoidCallback?   onTracksTap;

  const MediaKitGestureWrapper({
    super.key,
    required this.player,
    required this.controller,
    this.title       = '',
    this.onTracksTap,
  });

  @override
  State<MediaKitGestureWrapper> createState() => _MediaKitGestureWrapperState();
}

enum _HudType { seek }

class _MediaKitGestureWrapperState extends State<MediaKitGestureWrapper> {
  // ── HUD state ───────────────────────────────────────────────────────────────
  bool     _hudVisible  = false;
  double   _hudValue    = 0.0;   // 0.0 – 1.0
  _HudType _hudType     = _HudType.seek;
  Timer?   _hudTimer;

  // ── Gesture tracking (plain fields — no setState during drag) ───────────────
  double _volume      = 1.0;

  // ── Controls visibility ─────────────────────────────────────────────────────────
  bool   _showControls = false;
  Timer? _controlsTimer;

  // ── Playback state (listened from player stream) ──────────────────────────
  bool     _playing  = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  // Fix #3: threshold constants to avoid rebuilding on every position tick.
  // Position updates at up to 60 Hz; we only need ~1 Hz for the seek bar.
  static const _kPositionThreshold = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _stateSub = widget.player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    // Fix #3: only call setState when position changes by more than 500ms.
    // This reduces rebuilds from ~60/s to ~2/s during normal playback.
    _posSub = widget.player.stream.position.listen((p) {
      if (!mounted) return;
      final delta = (p - _position).abs();
      if (delta >= _kPositionThreshold) {
        setState(() => _position = p);
      }
    });
    // Fix #3: duration rarely changes — only rebuild when it actually differs.
    _durSub = widget.player.stream.duration.listen((d) {
      if (!mounted) return;
      if (d != _duration) {
        setState(() => _duration = d);
      }
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _controlsTimer?.cancel();
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  // ── HUD helpers ─────────────────────────────────────────────────────────────────

  void _showHud(_HudType type, double value) {
    _hudTimer?.cancel();
    // Single setState per drag update — only the HUD subtree rebuilds.
    setState(() { _hudVisible = true; _hudType = type; _hudValue = value; });
    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _hudVisible = false);
    });
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // ── Gesture handlers ─────────────────────────────────────────────────────────────

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _showControlsTemporarily();
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) =>
      value < min ? min : (value > max ? max : value);

  void _onDoubleTapDown(TapDownDetails d) {
    final isLeft = d.localPosition.dx < context.size!.width / 2;
    final delta  = const Duration(seconds: 10);
    final newPos = isLeft
        ? _clampDuration(_position - delta, Duration.zero, _duration)
        : _clampDuration(_position + delta, Duration.zero, _duration);
    widget.player.seek(newPos);
    HapticFeedback.selectionClick();
    // Show seek HUD briefly
    _showHud(_HudType.seek, newPos.inMilliseconds / _duration.inMilliseconds.clamp(1, 999999));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:           _onTap,
      onDoubleTapDown: _onDoubleTapDown,
      child: Stack(
        children: [
          // ── Video surface (RepaintBoundary isolates it from HUD repaints) ─────
          RepaintBoundary(
            child: ColoredBox(
              color: Colors.black,
              child: Video(
                controller: widget.controller,
                controls:   NoVideoControls, // we provide our own
                fill:       Colors.black,
              ),
            ),
          ),

          // ── Neon HUD overlay ───────────────────────────────────────────────────
          _NeonHud(
            visible:  _hudVisible,
            type:     _hudType,
            value:    _hudValue,
            seekMs:   null,
            duration: _duration,
          ),

          // ── Transport controls ───────────────────────────────────────────────────
          AnimatedOpacity(
            opacity:  _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _TransportControls(
                player:      widget.player,
                playing:     _playing,
                position:    _position,
                duration:    _duration,
                title:       widget.title,
                onTracksTap: widget.onTracksTap,
                onHide:      () => setState(() => _showControls = false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Neon HUD ────────────────────────────────────────────────────────────────────────────

/// Glassmorphic neon HUD that fades in/out over the video.
/// Only used for seek feedback; brightness/volume HUDs live in VideoGestureLayer.
/// Uses AnimatedOpacity so the fade is handled by the compositor —
/// no Dart-side animation controller needed, zero CPU overhead.
class _NeonHud extends StatelessWidget {
  final bool     visible;
  final _HudType type;
  final double   value;    // 0.0 – 1.0
  final Duration duration;

  const _NeonHud({
    required this.visible,
    required this.type,
    required this.value,
    required this.duration,
  });

  static const _amber = Color(0xFFF59E0B);

  Color get _neonColor => _amber;

  IconData get _icon => Icons.fast_forward_rounded;

  String get _label => '${(value * 100).toInt()}%';

  @override
  Widget build(BuildContext context) {
    final color = _neonColor;
    return AnimatedOpacity(
      opacity:  visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        child: Center(
          child: Container(
            // Multi-layer neon glow matching ModernNeonContainer style
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6,  spreadRadius: -2),
                BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 16, spreadRadius: -1),
                BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 32, spreadRadius:  0),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withValues(alpha: 0.35), width: 1.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, color: color, size: 32),
                    const SizedBox(height: 12),
                    // Progress bar
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _label,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: color, fontFamily: 'Inter',
                      ),
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
}

// ── Transport controls ───────────────────────────────────────────────────────────────────

class _TransportControls extends StatelessWidget {
  final Player      player;
  final bool        playing;
  final Duration    position;
  final Duration    duration;
  final String      title;
  final VoidCallback? onTracksTap;
  final VoidCallback  onHide;

  const _TransportControls({
    required this.player,
    required this.playing,
    required this.position,
    required this.duration,
    required this.title,
    required this.onHide,
    this.onTracksTap,
  });

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final durMs = duration.inMilliseconds.toDouble();
    final posMs = position.inMilliseconds.toDouble();
    final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

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
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w600, fontFamily: 'Inter',
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (onTracksTap != null)
                  IconButton(
                    icon: const Icon(Icons.subtitles_rounded,
                        color: Colors.white70, size: 22),
                    onPressed: onTracksTap,
                    tooltip: 'Audio / Subtitles',
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 22),
                  onPressed: onHide,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Center play/pause
          Center(
            child: GestureDetector(
              onTap: () => playing ? player.pause() : player.play(),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.black45,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.accent, size: 36,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Bottom seek bar + time
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) => player.seek(
                        Duration(milliseconds: (v * durMs).toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12,
                              fontFamily: 'Inter')),
                      Text(_fmt(duration),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12,
                              fontFamily: 'Inter')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
