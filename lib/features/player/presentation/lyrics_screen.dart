import 'package:flutter/material.dart';
// flutter/services.dart removed — all used elements are provided by flutter/material.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/media_item.dart';

// ── Provider ───────────────────────────────────────────────

final lyricsProvider =
    StateNotifierProvider.family<LyricsNotifier, LyricsState, MediaItem>(
  (ref, item) => LyricsNotifier(item),
);

class LyricsState {
  final List<String> lines;
  final bool isLoading;
  final bool hasError;
  final bool isOffline;
  const LyricsState({
    this.lines = const [],
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
    state = const LyricsState(isLoading: true);
    try {
      final artist = Uri.encodeComponent(item.artist ?? '');
      final title  = Uri.encodeComponent(item.title);
      final url =
          'https://api.lyrics.ovh/v1/$artist/$title';
      final res = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw  = data['lyrics'] as String? ?? '';
        final lines = raw
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        state = LyricsState(lines: lines);
      } else {
        state = const LyricsState(hasError: true);
      }
    } catch (_) {
      state = const LyricsState(hasError: true, isOffline: true);
    }
  }
}

// ── Lyrics Sheet ─────────────────────────────────────────────

class LyricsSheet extends ConsumerWidget {
  final MediaItem item;
  final Duration position;
  const LyricsSheet({super.key, required this.item, required this.position});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lyricsProvider(item));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
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
          // Header
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
                      fontFamily: 'SpaceGrotesk',
                    )),
                const Spacer(),
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          // Content
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent))
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
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        itemCount: state.lines.length,
                        itemBuilder: (context, i) {
                          // Highlight current line based on position
                          final approxLine = (position.inSeconds ~/
                                  (state.lines.isEmpty
                                      ? 1
                                      : 3))
                              .clamp(0, state.lines.length - 1);
                          final isActive = i == approxLine;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              state.lines[i],
                              style: TextStyle(
                                fontSize: isActive ? 17 : 14,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isActive
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                height: 1.5,
                                fontFamily: 'SpaceGrotesk',
                              ),
                            ),
                          ).animate(target: isActive ? 1 : 0).scaleXY(
                                begin: 1, end: 1.02, duration: 200.ms);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
