import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../core/database/otya_database.dart';
import '../../../core/models/media_item.dart';
import '../../../core/services/playback_coordinator.dart';

class LrcLine {
  const LrcLine({required this.timestamp, required this.text});

  final Duration timestamp;
  final String text;
}

class LyricsState {
  const LyricsState({
    this.lines = const [],
    this.lrcLines = const [],
    this.isLrc = false,
    this.isLoading = false,
    this.source,
  });

  final List<String> lines;
  final List<LrcLine> lrcLines;
  final bool isLrc;
  final bool isLoading;
  final String? source;

  bool get isEmpty => lines.isEmpty && lrcLines.isEmpty;
}

final lyricsProvider =
    StateNotifierProvider.family<LyricsNotifier, LyricsState, MediaItem>(
  (ref, item) => LyricsNotifier(item),
);

class LyricsNotifier extends StateNotifier<LyricsState> {
  LyricsNotifier(this.item) : super(const LyricsState(isLoading: true)) {
    _load();
  }

  final MediaItem item;

  Future<void> _load() async {
    // OTYA v1 deliberately does not send track metadata to an unaffiliated
    // lyrics service. Prefer a same-name .lrc file beside the media file.
    final sidecarPath = item.filePath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
    final sidecar = File(sidecarPath);
    if (await sidecar.exists()) {
      try {
        final raw = await sidecar.readAsString();
        final lrc = _parseLrc(raw);
        if (lrc.isNotEmpty) {
          state = LyricsState(
            lrcLines: lrc,
            isLrc: true,
            source: 'Local LRC',
          );
          return;
        }
        final plain = _splitPlain(raw);
        if (plain.isNotEmpty) {
          state = LyricsState(lines: plain, source: 'Local file');
          return;
        }
      } catch (_) {}
    }

    // Preserve lyrics already stored locally by an earlier OTYA build. New v1
    // installs do not fetch or populate this cache from a third-party service.
    final cached = OtyaDatabase.instance.getCachedLyrics(item.id);
    if (cached != null && cached.trim().isNotEmpty) {
      final lrc = _parseLrc(cached);
      if (lrc.isNotEmpty) {
        state = LyricsState(
          lrcLines: lrc,
          isLrc: true,
          source: 'Saved locally',
        );
        return;
      }
      final plain = _splitPlain(cached);
      if (plain.isNotEmpty) {
        state = LyricsState(lines: plain, source: 'Saved locally');
        return;
      }
    }

    state = const LyricsState();
  }

  List<LrcLine> _parseLrc(String raw) {
    final result = <LrcLine>[];
    final regex = RegExp(r'\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\](.*)');
    for (final rawLine in raw.split('\n')) {
      final match = regex.firstMatch(rawLine.trim());
      if (match == null) continue;
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = (match.group(3) ?? '0').padRight(3, '0');
      final millis = int.tryParse(fraction.substring(0, 3)) ?? 0;
      final text = match.group(4)?.trim() ?? '';
      if (text.isEmpty) continue;
      result.add(
        LrcLine(
          timestamp: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          ),
          text: text,
        ),
      );
    }
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  List<String> _splitPlain(String raw) => raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

class LyricsSheet extends ConsumerStatefulWidget {
  const LyricsSheet({
    super.key,
    required this.item,
    required this.position,
  });

  final MediaItem item;

  /// Fallback position when the sheet is opened without an active player.
  final Duration position;

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _activeIndex(List<LrcLine> lines, Duration position) {
    var active = -1;
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].timestamp <= position) {
        active = index;
      } else {
        break;
      }
    }
    return active;
  }

  void _keepActiveVisible(int index) {
    if (index < 0 || index == _lastActiveIndex) return;
    _lastActiveIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const estimatedHeight = 58.0;
      final target = index * estimatedHeight -
          (_scrollController.position.viewportDimension / 2) +
          estimatedHeight / 2;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: AppDimensions.motionEmphasized,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lyricsProvider(widget.item));
    final player = PlaybackCoordinator.instance.activePlayer;
    final positionStream = player?.stream.position;

    return FractionallySizedBox(
      heightFactor: .82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.lyrics_rounded, size: 21),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Lyrics',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (state.source != null)
                  Text(
                    state.source!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                IconButton(
                  tooltip: 'Close lyrics',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.isEmpty
                    ? _EmptyLyrics(item: widget.item)
                    : state.isLrc
                        ? StreamBuilder<Duration>(
                            stream: positionStream,
                            initialData: player?.state.position ?? widget.position,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? widget.position;
                              final active = _activeIndex(state.lrcLines, position);
                              _keepActiveVisible(active);
                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(24, 28, 24, 80),
                                itemCount: state.lrcLines.length,
                                itemBuilder: (context, index) {
                                  final line = state.lrcLines[index];
                                  final selected = index == active;
                                  return AnimatedDefaultTextStyle(
                                    duration: AppDimensions.motionFast,
                                    style: TextStyle(
                                      color: selected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: .56),
                                      fontSize: selected ? 20 : 16,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      height: 1.35,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Text(line.text),
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 60),
                            itemCount: state.lines.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, index) => Text(
                              state.lines[index],
                              style: const TextStyle(fontSize: 17, height: 1.5),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLyrics extends StatelessWidget {
  const _EmptyLyrics({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaName = item.filePath.split(Platform.pathSeparator).last;
    final lrcName = mediaName.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 52,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              const Text(
                'No local lyrics found',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              Text(
                'For private offline lyrics, place a matching $lrcName file beside this track. Timestamped LRC files will follow playback automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
