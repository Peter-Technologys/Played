import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/my_space/presentation/providers/my_space_provider.dart';
import '../../core/models/media_item.dart';

/// A dismissible banner that slides in from the top when new media files are
/// detected in the library (i.e. the item count increases after the first load).
///
/// - Auto-dismisses after 4 seconds.
/// - Debounced: will not re-appear within 10 seconds of the last show.
/// - Style: dark surface card with a cyan left border, slide-in from top.
///
/// Integrate by wrapping the shell body in a [Stack] and placing this widget
/// at the top of the stack.
class NewMediaBanner extends ConsumerStatefulWidget {
  const NewMediaBanner({super.key});

  @override
  ConsumerState<NewMediaBanner> createState() => _NewMediaBannerState();
}

class _NewMediaBannerState extends ConsumerState<NewMediaBanner> {
  // Track previous counts so we can detect increases.
  int? _prevVideoCount;
  int? _prevAudioCount;

  bool _visible = false;
  String _title = '';
  String _subtitle = '';

  Timer? _autoDismiss;
  DateTime? _lastShown;

  static const _debounce = Duration(seconds: 10);
  static const _autoDismissDuration = Duration(seconds: 4);

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  void _onLibraryChanged(List<MediaItem> items) {
    final videoCount = items.where((i) => i.isVideo).length;
    final audioCount = items.where((i) => !i.isVideo).length;

    final prevVideo = _prevVideoCount;
    final prevAudio = _prevAudioCount;

    _prevVideoCount = videoCount;
    _prevAudioCount = audioCount;

    // Skip on first load — we only care about increases after the initial scan.
    if (prevVideo == null || prevAudio == null) return;

    final newVideos = videoCount > prevVideo;
    final newAudios = audioCount > prevAudio;

    if (!newVideos && !newAudios) return;

    // Debounce: don't show again within 10 seconds.
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < _debounce) return;

    String title;
    String subtitle;
    if (newVideos && newAudios) {
      title = 'New files found! 🎵🎬';
      subtitle = 'Your library has been updated';
    } else if (newVideos) {
      title = 'New videos found! 🎬';
      subtitle = 'Your video list has been updated';
    } else {
      title = 'New songs found! 🎵';
      subtitle = 'Your music list has been updated';
    }

    _lastShown = now;
    _autoDismiss?.cancel();

    setState(() {
      _title = title;
      _subtitle = subtitle;
      _visible = true;
    });

    _autoDismiss = Timer(_autoDismissDuration, _dismiss);
  }

  void _dismiss() {
    _autoDismiss?.cancel();
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to library changes without rebuilding the whole widget tree.
    ref.listen<AsyncValue<List<MediaItem>>>(mediaLibraryProvider, (_, next) {
      next.whenData(_onLibraryChanged);
    });

    if (!_visible) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2F45)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Cyan left accent border
                  Container(
                    width: 4,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00BCD4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C94A8),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Dismiss button
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF8C94A8)),
                    onPressed: _dismiss,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            )
                .animate()
                .slideY(
                  begin: -1.5,
                  end: 0,
                  duration: 350.ms,
                  curve: Curves.easeOut,
                )
                .fadeIn(duration: 250.ms),
          ),
        ),
      ),
    );
  }
}
