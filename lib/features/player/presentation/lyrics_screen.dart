import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';
import '../../../core/database/played_database.dart';

// ── LRC line model ─────────────────────────────────────────────────

class LrcLine {
  final Duration timestamp;
  final String text;
  const LrcLine({required this.timestamp, required this.text});
}

// ── Provider ───────────────────────────────────────────────

final lyricsProvider =
    StateNotifierProvider.family<LyricsNotifier, LyricsState, MediaItem>(
  (ref, item) => LyricsNotifier(item),
);

class LyricsState {
  final List<String> lines;       // plain text lines (fallback)
  final List<LrcLine> lrcLines;   // timestamped LRC lines
  final bool isLrc;               // true when LRC is available
  final bool isLoading;
  final bool hasError;
  final bool isOffline;
  const LyricsState({
    this.lines = const [],
    this.lrcLines = const [],
    this.isLrc = false,
    this.isLoading = false,
    this.hasError = false,
    this.isOffline = false,
  });
}

class LyricsNotifier extends StateNotifier<LyricsState> {
  final MediaItem item;
  LyricsNotifier(this.item) : super(const LyricsState()) {
    fetch();
  }

  Future<void> fetch() async {
    // 1. Check for a local .lrc file alongside the audio file
    final lrcPath = item.filePath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
    final lrcFile = File(lrcPath);
    if (await lrcFile.exists()) {
      try {
        final raw = await lrcFile.readAsString();
        final parsed = _parseLrc(raw);
        if (parsed.isNotEmpty) {
          state = LyricsState(lrcLines: parsed, isLrc: true);
          return;
        }
      } catch (_) {}
    }

    // 2. Check offline plain-text cache
    final cached = PlayedDatabase.instance.getCachedLyrics(item.id);
    if (cached != null) {
      // Try to parse as LRC first
      final parsed = _parseLrc(cached);
      if (parsed.isNotEmpty) {
        state = LyricsState(lrcLines: parsed, isLrc: true);
        return;
      }
      final lines = _splitPlain(cached);
      state = LyricsState(lines: lines);
      return;
    }

    // 3. Fetch from network
    state = const LyricsState(isLoading: true);
    try {
      final artist = Uri.encodeComponent(item.artist ?? '');
      final title  = Uri.encodeComponent(item.title);
      final url = 'https://api.lyrics.ovh/v1/$artist/$title';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw  = data['lyrics'] as String? ?? '';
        await PlayedDatabase.instance.cacheLyrics(item.id, raw);
        final parsed = _parseLrc(raw);
        if (parsed.isNotEmpty) {
          state = LyricsState(lrcLines: parsed, isLrc: true);
        } else {
          state = LyricsState(lines: _splitPlain(raw));
        }
      } else {
        state = const LyricsState(hasError: true);
      }
    } catch (_) {
      state = const LyricsState(hasError: true, isOffline: true);
    }
  }

  /// Parse LRC format: [mm:ss.xx] lyric line
  List<LrcLine> _parseLrc(String raw) {
    final result = <LrcLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d+))?\](.*)');
    for (final line in raw.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millis  = int.tryParse((match.group(3) ?? '0').padRight(3, '0').substring(0, 3)) ?? 0;
        final text    = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          result.add(LrcLine(
            timestamp: Duration(
                minutes: minutes, seconds: seconds, milliseconds: millis),
            text: text,
          ));
        }
      }
    }
    return result;
  }

  List<String> _splitPlain(String raw) => raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

// ── Lyrics Sheet ─────────────────────────────────────────────

class LyricsSheet extends ConsumerStatefulWidget {
  final MediaItem item;
  final Duration position;
  const LyricsSheet({super.key, required this.item, required this.position});

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  final ScrollController _scroll = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Auto-scroll to keep the active line centred.
  void _scrollToActive(int index) {
    if (!_scroll.hasClients) return;
    if (index == _lastActiveIndex) return;
    _lastActiveIndex = index;
    const itemHeight = 52.0;
    final target = (index * itemHeight) -
        (_scroll.position.viewportDimension / 2) +
        itemHeight / 2;
    _scroll.animateTo(
      target.clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lyricsProvider(widget.item));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.lyrics_rounded,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Text('Lyrics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    )),
                if (state.isLrc) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Text('SYNC',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 0.8,
                        )),
                  ),
                ],
                const Spacer(),
                Text(widget.item.title,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : state.hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              state.isOffline
                                  ? Icons.wifi_off_rounded
                                  : Icons.lyrics_outlined,
                              color: AppColors.textSecondary,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.isOffline
                                  ? 'Connect to internet to fetch lyrics'
                                  : 'Lyrics not found for this track',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : state.isLrc
                        ? _LrcView(
                            lines: state.lrcLines,
                            position: widget.position,
                            scroll: _scroll,
                            onActiveIndex: _scrollToActive,
                          )
                        : _PlainView(
                            lines: state.lines,
                            position: widget.position,
                          ),
          ),
        ],
      ),
    );
  }
}

// ── LRC synced view ────────────────────────────────────────────────

class _LrcView extends StatelessWidget {
  final List<LrcLine> lines;
  final Duration position;
  final ScrollController scroll;
  final ValueChanged<int> onActiveIndex;

  const _LrcView({
    required this.lines,
    required this.position,
    required this.scroll,
    required this.onActiveIndex,
  });

  int get _active {
    int a = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timestamp <= position) a = i;
    }
    return a;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    WidgetsBinding.instance.addPostFrameCallback((_) => onActiveIndex(active));

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            lines[i].text,
            style: TextStyle(
              fontSize: isActive ? 18 : 14,
              fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? AppColors.accent
                  : AppColors.textSecondary,
              height: 1.5,
              fontFamily: 'Inter',
            ),
          ),
        ).animate(target: isActive ? 1 : 0).scaleXY(
              begin: 1, end: 1.03, duration: 200.ms);
      },
    );
  }
}

// ── Plain text view ────────────────────────────────────────────────

class _PlainView extends StatelessWidget {
  final List<String> lines;
  final Duration position;

  const _PlainView({required this.lines, required this.position});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        // Estimate active line proportionally using playback position.
        // We don't know total duration here, so we use a rolling 3-min
        // assumption (180 s) which is reasonable for most songs.
        // This is still an approximation — only LRC files give true sync.
        const estimatedTotalSec = 180;
        final fraction = lines.isEmpty
            ? 0.0
            : (position.inSeconds / estimatedTotalSec).clamp(0.0, 1.0);
        final approxLine =
            (fraction * (lines.length - 1)).round().clamp(0, lines.length - 1);
        final isActive = i == approxLine;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            lines[i],
            style: TextStyle(
              fontSize: isActive ? 17 : 14,
              fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? AppColors.accent
                  : AppColors.textSecondary,
              height: 1.5,
              fontFamily: 'Inter',
            ),
          ),
        ).animate(target: isActive ? 1 : 0).scaleXY(
              begin: 1, end: 1.02, duration: 200.ms);
      },
    );
  }
}
