import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import '../../core/services/new_media_tracker.dart';
import 'new_badge.dart';

/// Rebuilds when the local unseen-media set changes and renders nothing once
/// the media has been opened/played. Safe to place beside a title or on top of
/// a thumbnail without changing the surrounding layout.
class MediaNewIndicator extends StatefulWidget {
  final MediaItem item;
  const MediaNewIndicator({super.key, required this.item});

  @override
  State<MediaNewIndicator> createState() => _MediaNewIndicatorState();
}

class _MediaNewIndicatorState extends State<MediaNewIndicator> {
  @override
  void initState() {
    super.initState();
    NewMediaTracker.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    NewMediaTracker.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!NewMediaTracker.instance.isUnseen(widget.item)) {
      return const SizedBox.shrink();
    }
    return const OtyaNewBadge();
  }
}
