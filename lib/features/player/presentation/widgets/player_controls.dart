// player_controls.dart — stub, no longer uses flutter_vlc_player.
// VideoPlayerScreen now uses MediaKitEngine directly.
import 'package:flutter/material.dart';
import '../../../../core/models/media_item.dart';

enum AspectMode { fit, fill, ratio169, ratio43 }

class PlayerControls extends StatelessWidget {
  final MediaItem    mediaItem;
  final VoidCallback onBack;
  final VoidCallback? onPip;
  final VoidCallback? onLockScreen;
  const PlayerControls({
    super.key,
    required this.mediaItem,
    required this.onBack,
    this.onPip,
    this.onLockScreen,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
