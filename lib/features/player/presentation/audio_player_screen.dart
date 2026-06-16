import 'dart:io';
import 'package:audio_service/audio_service.dart' hide MediaItem;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/database/played_database.dart';
import '../../../core/services/audio_handler.dart';
import '../../../core/services/vault_service.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../features/settings/settings_provider.dart';
import 'mini_player.dart';
import 'queue_screen.dart';
import 'lyrics_screen.dart';
import 'file_info_sheet.dart';
import 'car_mode_screen.dart';
import 'widgets/sleep_timer.dart';

// ── State ──────────────────────────────────────────────────────

enum RepeatState { off, one, all }

class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool isLoading;
  final bool isFavorite;
  final bool isShuffle;
  final RepeatState repeat;

  const AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.isLoading = true,
    this.isFavorite = false,
    this.isShuffle = false,
    this.repeat = RepeatState.off,
  });

  AudioPlayerState copyWith({
    bool? isPlaying, Duration? position, Duration? duration,
    double? speed, bool? isLoading, bool? isFavorite,
    bool? isShuffle, RepeatState? repeat,
  }) => AudioPlayerState(
    isPlaying: isPlaying ?? this.isPlaying,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    isLoading: isLoading ?? this.isLoading,
    isFavorite: isFavorite ?? this.isFavorite,
    isShuffle: isShuffle ?? this.isShuffle,
    repeat: repeat ?? this.repeat,
  );
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  // Route all playback through the audio_service handler.
  // This gives us the notification media player for free.
  PlayedAudioHandler get _handler => globalAudioHandler!;
  AudioPlayer get _player => _handler.player;
  String? _currentItemId;

  AudioPlayerNotifier() : super(const AudioPlayerState()) {
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      state = state.copyWith(
        isPlaying: s.playing,
        isLoading: s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      );
    });
    _player.positionStream.listen((p) {
      if (!mounted) return;
      state = state.copyWith(position: p);
      // Autosave seek position every 5 seconds
      if (_currentItemId != null && p.inSeconds % 5 == 0 && p.inSeconds > 0) {
        PlayedDatabase.instance.saveSeekPosition(_currentItemId!, p);
      }
    });
    _player.durationStream.listen((d) {
      if (!mounted) return;
      if (d != null) state = state.copyWith(duration: d);
    });
    // Auto-advance to next track when current finishes
    _player.processingStateStream.listen((ps) {
      if (ps == ProcessingState.completed) {
        _onTrackComplete();
      }
    });
  }

  void _onTrackComplete() {
    // Handled by the screen via repeat/queue logic
  }

  // Keep a reference to the ProviderContainer so load() can update
  // miniPlayerItemProvider without needing a BuildContext.
  ProviderContainer? _container;

  void attachContainer(ProviderContainer container) {
    _container = container;
  }

  Future<void> load(MediaItem item, {AppSettings? settings}) async {
    _currentItemId = item.id;
    state = state.copyWith(isLoading: true, isFavorite: _loadFavorite(item.id));
    _container?.read(miniPlayerItemProvider.notifier).state = item;

    final saved       = PlayedDatabase.instance.getSeekPosition(item.id);
    final speed       = settings?.playbackSpeed ?? state.speed;
    final skipSilence = settings?.skipSilence ?? false;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // loadAndPlay goes through audio_service — creates the notification
    await _handler.loadAndPlay(
      item,
      speed: speed,
      skipSilence: skipSilence,
      savedPosition: saved,
    );
    state = state.copyWith(speed: speed);
    PlayedDatabase.instance.recordPlay(item);
  }

  bool _loadFavorite(String id) {
    // Favorites persisted in Hive seekPositions box reused as flags box
    // We use a dedicated key prefix to avoid collision
    final data = PlayedDatabase.instance.getFavoriteFlag(id);
    return data;
  }

  void togglePlay() => _player.playing ? _handler.pause() : _handler.play();
  void pause()      => _handler.pause();
  Future<void> seek(Duration p) => _handler.seek(p);
  Future<void> skipForward() =>
      _handler.seek(state.position + const Duration(seconds: 10));
  Future<void> skipBack() =>
      _handler.seek(state.position - const Duration(seconds: 10));

  void skipNext() {
    if (_container == null) return;
    _container!.read(queueProvider.notifier).next();
    final next = _container!.read(queueProvider).current;
    if (next != null) load(next);
  }

  void skipPrevious() {
    if (state.position.inSeconds > 3) {
      _handler.seek(Duration.zero);
      return;
    }
    if (_container == null) return;
    _container!.read(queueProvider.notifier).previous();
    final prev = _container!.read(queueProvider).current;
    if (prev != null) load(prev);
  }

  void setSpeed(double s) {
    _handler.setSpeed(s);
    state = state.copyWith(speed: s);
  }

  void toggleFavorite() {
    final next = !state.isFavorite;
    state = state.copyWith(isFavorite: next);
    if (_currentItemId != null) {
      PlayedDatabase.instance.setFavoriteFlag(_currentItemId!, next);
    }
  }

  void toggleShuffle()  => state = state.copyWith(isShuffle: !state.isShuffle);

  void cycleRepeat() {
    final next = RepeatState.values[
        (state.repeat.index + 1) % RepeatState.values.length];
    state = state.copyWith(repeat: next);
    switch (next) {
      case RepeatState.off: _player.setLoopMode(LoopMode.off);
      case RepeatState.one: _player.setLoopMode(LoopMode.one);
      case RepeatState.all: _player.setLoopMode(LoopMode.all);
    }
  }

  void savePosition(String id) =>
      PlayedDatabase.instance.saveSeekPosition(id, state.position);

  @override
  void dispose() {
    // Do NOT stop the handler — it lives for the app lifetime
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) {
    final notifier = AudioPlayerNotifier();
    // Give the notifier access to the provider container so it can
    // update miniPlayerItemProvider when a track loads.
    notifier.attachContainer(ref.container);
    return notifier;
  },
);

// ── Screen ─────────────────────────────────────────────────────

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  const AudioPlayerScreen({super.key, required this.mediaItem});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      // load() already calls PlayedDatabase.instance.recordPlay() internally
      // — do not call it again here to avoid double-counting play history.
      ref.read(audioPlayerProvider.notifier).load(
        widget.mediaItem,
        settings: settings,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      ref.read(audioPlayerProvider.notifier).savePosition(widget.mediaItem.id);
    }
  }

  @override
  void dispose() {
    ref.read(audioPlayerProvider.notifier).savePosition(widget.mediaItem.id);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showQueue() => showModalBottomSheet(
    context: context, backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const QueueScreen(),
  );

  void _showLyrics(Duration pos) => showModalBottomSheet(
    context: context, backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => LyricsSheet(item: widget.mediaItem, position: pos),
  );

  void _showFileInfo() => showModalBottomSheet(
    context: context, backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => FileInfoSheet(item: widget.mediaItem),
  );

  void _showOptions() => showModalBottomSheet(
    context: context, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _OptionsSheet(
      mediaItem: widget.mediaItem,
      onFileInfo:        () { Navigator.pop(context); _showFileInfo(); },
      onOpenInStudio:    () { Navigator.pop(context); context.push('/studio'); },
      onTrimForWhatsApp: () {
        Navigator.pop(context);
        context.push('/tools/whatsapp', extra: widget.mediaItem);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ps = ref.watch(audioPlayerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text('NOW PLAYING',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.5, fontFamily: 'Inter',
                      )),
                  const Spacer(),
                  SleepTimerButton(
                    onExpire: () =>
                        ref.read(audioPlayerProvider.notifier).pause(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.textSecondary, size: 22),
                    onPressed: _showOptions,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
                child: _AlbumArt(
                  albumArtPath: widget.mediaItem.albumArtPath,
                  isPlaying: ps.isPlaying,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.mediaItem.title,
                            style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(widget.mediaItem.artist ?? 'Unknown Artist',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary,
                                fontFamily: 'Inter'),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).toggleFavorite(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        ps.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(ps.isFavorite),
                        color: ps.isFavorite
                            ? Colors.redAccent
                            : AppColors.textSecondary,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SeekBar(
                position: ps.position,
                duration: ps.duration,
                onSeek: (d) =>
                    ref.read(audioPlayerProvider.notifier).seek(d),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ToggleIconBtn(
                    icon: Icons.shuffle_rounded,
                    active: ps.isShuffle,
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).toggleShuffle(),
                  ),
                  GestureDetector(
                    onTap: () {
                      const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
                      final idx = speeds.indexOf(ps.speed);
                      ref.read(audioPlayerProvider.notifier)
                          .setSpeed(speeds[(idx + 1) % speeds.length]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('${ps.speed}x',
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            fontFamily: 'Inter',
                          )),
                    ),
                  ),
                  _RepeatBtn(
                    repeat: ps.repeat,
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).cycleRepeat(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: AppColors.textPrimary, size: 34),
                    onPressed: () =>
                        ref.read(audioPlayerProvider.notifier).skipPrevious(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded,
                        color: AppColors.textPrimary, size: 34),
                    onPressed: () =>
                        ref.read(audioPlayerProvider.notifier).skipBack(),
                  ),
      // Gradient play button
                  GestureDetector(
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).togglePlay(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentViolet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.45),
                            blurRadius: 28, spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ps.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : Icon(
                              ps.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black, size: 38,
                            ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded,
                        color: AppColors.textPrimary, size: 34),
                    onPressed: () =>
                        ref.read(audioPlayerProvider.notifier).skipForward(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                        color: AppColors.textPrimary, size: 34),
                    onPressed: () =>
                        ref.read(audioPlayerProvider.notifier).skipNext(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SecondaryBtn(
                    icon: Icons.lyrics_rounded,
                    label: 'Lyrics',
                    onTap: () => _showLyrics(ps.position),
                  ),
                  _SecondaryBtn(
                    icon: Icons.equalizer_rounded,
                    label: 'EQ',
                    onTap: () => context.push('/player/equalizer'),
                  ),
                  _SecondaryBtn(
                    icon: Icons.queue_music_rounded,
                    label: 'Queue',
                    onTap: _showQueue,
                  ),
                  _SecondaryBtn(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: () => Share.shareXFiles(
                      [XFile(widget.mediaItem.filePath)],
                      text: widget.mediaItem.title,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Album Art ──────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final String? albumArtPath;
  final bool isPlaying;
  const _AlbumArt({this.albumArtPath, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      transform: Matrix4.diagonal3Values(
          isPlaying ? 1.0 : 0.88,
          isPlaying ? 1.0 : 0.88,
          1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: isPlaying ? 0.35 : 0.1),
            blurRadius: isPlaying ? 48 : 16,
            spreadRadius: isPlaying ? 6 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: albumArtPath != null && !albumArtPath!.startsWith('albumid:')
            ? Image.file(File(albumArtPath!),
                fit: BoxFit.cover, width: double.infinity)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.15),
                      AppColors.accentViolet.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppColors.accent.withValues(
                        alpha: isPlaying ? 0.9 : 0.5),
                    size: 80,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Seek Bar ───────────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  const _SeekBar(
      {required this.position, required this.duration, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: progress,
            onChanged: (v) => onSeek(
                Duration(milliseconds: (v * duration.inMilliseconds).toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DurationFormatter.format(position),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text(DurationFormatter.format(duration),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Toggle Icon Button ─────────────────────────────────────────

class _ToggleIconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToggleIconBtn(
      {required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Icon(icon,
          color: active ? AppColors.accent : AppColors.textSecondary,
          size: 24),
    );
  }
}

// ── Repeat Button ──────────────────────────────────────────────

class _RepeatBtn extends StatelessWidget {
  final RepeatState repeat;
  final VoidCallback onTap;
  const _RepeatBtn({required this.repeat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = repeat == RepeatState.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    final active = repeat != RepeatState.off;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Icon(icon,
          color: active ? AppColors.accent : AppColors.textSecondary,
          size: 24),
    );
  }
}

// ── Secondary Button ───────────────────────────────────────────

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                fontSize: 10, color: AppColors.accent,
                fontFamily: 'Inter', fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

// ── Options Sheet ──────────────────────────────────────────────

class _OptionsSheet extends ConsumerWidget {
  final MediaItem mediaItem;
  final VoidCallback onFileInfo;
  final VoidCallback onOpenInStudio;
  final VoidCallback onTrimForWhatsApp;
  const _OptionsSheet({
    required this.mediaItem,
    required this.onFileInfo,
    required this.onOpenInStudio,
    required this.onTrimForWhatsApp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = [
      _Opt(Icons.directions_car_rounded, 'Car Mode', AppColors.accent, () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CarModeScreen()),
        );
      }),
      _Opt(Icons.playlist_add_rounded, 'Add to Playlist', AppColors.accent, () {
        ref.read(queueProvider.notifier).addToQueue(mediaItem);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to queue')));
      }),
      _Opt(Icons.lock_rounded, 'Move to Vault', AppColors.accentViolet, () async {
        Navigator.pop(context);
        await VaultService.instance.lockItem(mediaItem);
        if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Moved to Vault'))); }
      }),
      _Opt(Icons.wifi_tethering_rounded, 'Share via Air-Drop', AppColors.accent, () {
        Navigator.pop(context);
        context.go('/airdrop');
      }),
      _Opt(Icons.graphic_eq_rounded,    'Open in Studio',      AppColors.accentViolet, onOpenInStudio),
      _Opt(Icons.phone_android_rounded, 'Trim for WhatsApp',   AppColors.accent,       onTrimForWhatsApp),
      _Opt(Icons.download_rounded, 'Extract Audio (MP3)', AppColors.accent, () async {
        Navigator.pop(context);
        await FfmpegService.instance.extractAudio(
            videoPath: mediaItem.filePath, onProgress: (_) {});
        if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio extracted to Downloads'))); }
      }),
      _Opt(Icons.cast_rounded, 'Cast to Device', AppColors.textSecondary, () {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Cast to Device',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            content: const Text(
              'Chromecast / DLNA casting is coming in a future update.\n\n'
              'For now, use Air-Drop to send files to nearby devices.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Got it', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }),
      _Opt(Icons.info_outline_rounded, 'File Info', AppColors.textSecondary, onFileInfo),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.music_note_rounded,
                    color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mediaItem.title,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(mediaItem.formattedSize,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          ...options.map((o) => ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: o.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(o.icon, color: o.color, size: 18),
                ),
                title: Text(o.label,
                    style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    )),
                onTap: () {
                  if (o.onTap != null) { o.onTap!(); }
                  else { Navigator.pop(context); }
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                dense: true,
              )),
        ],
      ),
    );
  }
}

class _Opt {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Opt(this.icon, this.label, this.color, this.onTap);
}
