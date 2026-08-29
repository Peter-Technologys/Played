import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/models/media_item.dart';
import '../../core/services/otya_support_service.dart';
import '../my_space/presentation/providers/my_space_provider.dart';

class SmartSearchSheet extends ConsumerStatefulWidget {
  const SmartSearchSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: AppColors.cardOf(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const FractionallySizedBox(
          heightFactor: .92,
          child: SmartSearchSheet(),
        ),
      );

  @override
  ConsumerState<SmartSearchSheet> createState() => _SmartSearchSheetState();
}

class _HelpHit {
  final String title;
  final String answer;
  final List<String> keywords;

  const _HelpHit(this.title, this.answer, this.keywords);
}

class _SmartSearchSheetState extends ConsumerState<SmartSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _ai = OtyaSupportService.instance;

  String _query = '';
  String? _aiAnswer;
  String? _aiError;
  bool _asking = false;

  static const _help = <_HelpHit>[
    _HelpHit(
      'Add subtitles',
      'Open a video, open the player track/subtitle controls, then choose an embedded subtitle track when available.',
      ['subtitle', 'subtitles', 'caption', 'captions'],
    ),
    _HelpHit(
      'Media is missing',
      'Open OTYA Settings and review media permissions, then refresh the Video or Music library. OTYA scans local device media without requiring an account.',
      ['missing', 'scan', 'media', 'not showing', 'library', 'permission'],
    ),
    _HelpHit(
      'Transfer files',
      'Open Me → Transfer. The sender and receiver should be on the same Wi-Fi or hotspot. Scan the sender QR code or use its local link.',
      ['transfer', 'send', 'receive', 'nearby', 'qr', 'computer', 'pc'],
    ),
    _HelpHit(
      'Convert video to audio',
      'Open Me → Converter, choose a local video, then OTYA extracts its existing audio track on the device. No upload is required.',
      ['convert', 'converter', 'video audio', 'extract audio', 'm4a'],
    ),
    _HelpHit(
      'Private media',
      'Open Me → Private to use OTYA’s protected local media area. Keep your device PIN/biometric secure and never share recovery or verification codes.',
      ['private', 'vault', 'lock', 'hide media'],
    ),
    _HelpHit(
      'Downloads in Video and Music',
      'Playable files in your device Download/Downloads folders are part of OTYA’s normal media library, so videos appear in Video and songs appear in Music after scanning.',
      ['download', 'downloads', 'downloaded', 'folder'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_focusNode.requestFocus);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<MediaItem> _mediaMatches(List<MediaItem> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const <MediaItem>[];
    return items.where((item) {
      return item.title.toLowerCase().contains(q) ||
          (item.artist?.toLowerCase().contains(q) ?? false) ||
          (item.album?.toLowerCase().contains(q) ?? false) ||
          item.filePath.toLowerCase().split('/').last.contains(q);
    }).take(30).toList(growable: false);
  }

  List<_HelpHit> _helpMatches() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const <_HelpHit>[];
    return _help.where((entry) {
      if (entry.title.toLowerCase().contains(q)) return true;
      return entry.keywords.any((keyword) =>
          q.contains(keyword) || keyword.contains(q));
    }).take(4).toList(growable: false);
  }

  Future<void> _askAi() async {
    final q = _query.trim();
    if (q.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _aiAnswer = null;
      _aiError = null;
    });
    try {
      final reply = await _ai.ask(q);
      if (!mounted) return;
      setState(() => _aiAnswer = reply.answer);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiError =
            'Online answers are unavailable right now. Local media search and OTYA help still work.';
      });
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _openMedia(MediaItem item) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.push(item.isVideo ? '/player/video' : '/player/audio', extra: item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(mediaLibraryProvider).valueOrNull ?? const <MediaItem>[];
    final media = _mediaMatches(library);
    final help = _helpMatches();
    final hasQuery = _query.trim().isNotEmpty;
    final noLocalAnswer = hasQuery && media.isEmpty && help.isEmpty;

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if (noLocalAnswer) _askAi();
            },
            onChanged: (value) => setState(() {
              _query = value;
              _aiAnswer = null;
              _aiError = null;
            }),
            decoration: InputDecoration(
              hintText: 'Search media or ask OTYA',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _query = '';
                          _aiAnswer = null;
                          _aiError = null;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: !hasQuery
              ? const _SearchStart()
              : ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  children: [
                    if (media.isNotEmpty) ...[
                      _SectionLabel('On this device', '${media.length} found'),
                      ...media.map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.cardOf(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.borderOf(context),
                              ),
                            ),
                            child: Icon(
                              item.isVideo
                                  ? Icons.movie_outlined
                                  : Icons.music_note_rounded,
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            item.isVideo
                                ? '${item.formattedDuration} · ${item.formattedSize}'
                                : (item.artist ?? item.formattedDuration),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.play_arrow_rounded,
                            size: 20,
                          ),
                          onTap: () => _openMedia(item),
                        ),
                      ),
                    ],
                    if (help.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SectionLabel('OTYA help', '${help.length} match'),
                      ...help.map(
                        (entry) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.borderOf(context),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.answer,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (noLocalAnswer || _aiAnswer != null || _aiError != null) ...[
                      const SizedBox(height: 8),
                      _SectionLabel('Ask OTYA', noLocalAnswer ? 'Online' : ''),
                      if (_aiAnswer != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cardOf(context),
                            border: Border.all(
                              color: AppColors.borderOf(context),
                            ),
                          ),
                          child: SelectableText(
                            _aiAnswer!,
                            style: const TextStyle(fontSize: 13, height: 1.55),
                          ),
                        )
                      else if (_aiError != null)
                        Text(
                          _aiError!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _asking ? null : _askAi,
                            icon: _asking
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              _asking ? 'Thinking…' : 'Ask about “${_query.trim()}”',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SearchStart extends StatelessWidget {
  const _SearchStart();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.manage_search_rounded,
                size: 46,
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Search OTYA',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                'OTYA searches your local music and videos first. Help works offline. Online AI is only used when you ask for it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .58),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String detail;
  const _SectionLabel(this.title, this.detail);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
            if (detail.isNotEmpty) ...[
              const Spacer(),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
}
