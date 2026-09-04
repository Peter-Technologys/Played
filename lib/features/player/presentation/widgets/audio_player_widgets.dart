part of '../audio_player_screen.dart';

class _AlbumArt extends StatefulWidget {
  final String? albumArtPath;
  final bool isPlaying;
  final String title;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const _AlbumArt({
    this.albumArtPath,
    required this.isPlaying,
    this.title = '',
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  State<_AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<_AlbumArt> {
  String? _resolvedPath;
  bool _loading = true;
  double _dragX = 0;
  int _resolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_AlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumArtPath != widget.albumArtPath) _resolve();
  }

  Future<void> _resolve() async {
    final generation = ++_resolveGeneration;
    final path = widget.albumArtPath;
    if (path == null) {
      if (mounted && generation == _resolveGeneration) {
        setState(() {
          _resolvedPath = null;
          _loading = false;
        });
      }
      return;
    }
    if (!path.startsWith('albumid:')) {
      if (mounted && generation == _resolveGeneration) {
        setState(() {
          _resolvedPath = path;
          _loading = false;
        });
      }
      return;
    }

    if (mounted && generation == _resolveGeneration) {
      setState(() => _loading = true);
    }
    final resolved = await AlbumArtService.instance.resolve(path);
    if (!mounted || generation != _resolveGeneration) return;
    setState(() {
      _resolvedPath = resolved;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showArt = !_loading && _resolvedPath != null;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() => _dragX += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragX < -60 || velocity < -400) {
          HapticFeedback.mediumImpact();
          widget.onSwipeLeft?.call();
        } else if (_dragX > 60 || velocity > 400) {
          HapticFeedback.mediumImpact();
          widget.onSwipeRight?.call();
        }
        setState(() => _dragX = 0);
      },
      onHorizontalDragCancel: () => setState(() => _dragX = 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_dragX < -20)
            Positioned(
              right: 12,
              child: AnimatedOpacity(
                opacity: (_dragX.abs() / 80).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 80),
                child: const Icon(
                  Icons.skip_next_rounded,
                  color: AppColors.accent,
                  size: 40,
                ),
              ),
            ),
          if (_dragX > 20)
            Positioned(
              left: 12,
              child: AnimatedOpacity(
                opacity: (_dragX.abs() / 80).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 80),
                child: const Icon(
                  Icons.skip_previous_rounded,
                  color: AppColors.accent,
                  size: 40,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragX.clamp(-40.0, 40.0), 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              transform: Matrix4.diagonal3Values(
                widget.isPlaying ? 1.0 : 0.97,
                widget.isPlaying ? 1.0 : 0.97,
                1.0,
              ),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: widget.isPlaying ? 0.14 : 0.06,
                    ),
                    blurRadius: widget.isPlaying ? 34 : 20,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: showArt
                    ? RepaintBoundary(
                        child: Image.file(
                          File(_resolvedPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          cacheWidth: 600,
                        ),
                      )
                    : _DynamicArtPlaceholder(
                        title: widget.title,
                        isPlaying: widget.isPlaying,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicArtPlaceholder extends StatelessWidget {
  final String title;
  final bool isPlaying;

  const _DynamicArtPlaceholder({
    required this.title,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final letter = title.isNotEmpty ? title[0].toUpperCase() : '♪';
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surfaceElevated,
                AppColors.accent.withValues(alpha: 0.16),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(color: Colors.transparent),
        ),
        Center(child: _VinylRing(isPlaying: isPlaying)),
        Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w900,
              color: AppColors.accent.withValues(
                alpha: isPlaying ? 0.95 : 0.60,
              ),
              fontFamily: 'Inter',
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _VinylRing extends StatelessWidget {
  final bool isPlaying;

  const _VinylRing({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.18),
          width: 28,
        ),
      ),
    );

    if (!isPlaying) return ring;
    return ring
        .animate(onPlay: (controller) => controller.repeat())
        .rotate(duration: 4000.ms, curve: Curves.linear);
  }
}

class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 5,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: progress,
            onChanged: duration.inMilliseconds <= 0
                ? null
                : (value) => onSeek(
                      Duration(
                        milliseconds: (value * duration.inMilliseconds).toInt(),
                      ),
                    ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.format(position),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                DurationFormatter.format(duration),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleIconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleIconBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = icon == Icons.shuffle_rounded
        ? (active ? 'Shuffle on' : 'Shuffle off')
        : (active ? 'Option on' : 'Option off');
    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Icon(
        icon,
        color: active ? AppColors.accent : AppColors.textSecondary,
        size: 24,
      ),
    );
  }
}

class _RepeatBtn extends StatelessWidget {
  final RepeatState repeat;
  final VoidCallback onTap;

  const _RepeatBtn({required this.repeat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = repeat == RepeatState.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
    final tooltip = switch (repeat) {
      RepeatState.off => 'Repeat off',
      RepeatState.one => 'Repeat one',
      RepeatState.all => 'Repeat all',
    };
    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Icon(
        icon,
        color: repeat == RepeatState.off
            ? AppColors.textSecondary
            : AppColors.accent,
        size: 24,
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Icon(icon, color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsSheet extends ConsumerWidget {
  final MediaItem mediaItem;
  final VoidCallback onFileInfo;

  const _OptionsSheet({
    required this.mediaItem,
    required this.onFileInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = [
      _Opt(Icons.directions_car_rounded, 'Drive Mode', AppColors.accent, () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CarModeScreen()),
        );
      }),
      _Opt(Icons.playlist_add_rounded, 'Queue It', AppColors.accent, () {
        ref.read(queueProvider.notifier).addToQueue(mediaItem);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Queued!')),
        );
      }),
      _Opt(Icons.lock_rounded, 'Move to Private', AppColors.textSecondary, () async {
        Navigator.pop(context);
        await VaultService.instance.lockItem(mediaItem);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Moved to Private')),
          );
        }
      }),
      _Opt(Icons.send_rounded, 'Transfer', AppColors.accent, () {
        Navigator.pop(context);
        context.go('/transfer');
      }),
      _Opt(Icons.info_outline_rounded, 'Details', AppColors.textSecondary, onFileInfo),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mediaItem.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      mediaItem.formattedSize,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          ...options.map(
            (option) => ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(option.icon, color: option.color, size: 18),
              ),
              title: Text(
                option.label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              onTap: option.onTap,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Opt {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Opt(this.icon, this.label, this.color, this.onTap);
}
