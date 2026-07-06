// VlcPlayerAdapter — bridges VlcPlayerController to OtyaVideoPanel.
//
// Usage in VideoPlayerScreen:
//   late VlcPlayerAdapter _adapter;
//   // after _vlcController is created:
//   _adapter = VlcPlayerAdapter(_vlcController);
//   // in dispose(): _adapter.dispose();
//
// Replace GestureDetectorLayer + PlayerControls with:
//   OtyaVideoPanel(adapter: _adapter, title: widget.mediaItem.title)

import 'package:flutter/foundation.dart'; // VoidCallback
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'otya_video_panel.dart';

class VlcPlayerAdapter implements VideoPlayerAdapter {
  final VlcPlayerController controller;
  bool _isFullScreen = false;
  final List<VoidCallback> _extra = [];

  VlcPlayerAdapter(this.controller);

  @override bool     get isPlaying    => controller.value.isPlaying;
  @override bool     get isFullScreen => _isFullScreen;
  @override Duration get position     => controller.value.position;
  @override Duration get duration     => controller.value.duration;
  @override double   get speed        => controller.value.playbackSpeed;

  @override
  Duration get bufferedPosition {
    final pct = controller.value.bufferPercent / 100.0;
    return Duration(
        milliseconds:
            (controller.value.duration.inMilliseconds * pct).toInt());
  }

  @override void play()             => controller.play();
  @override void pause()            => controller.pause();
  @override void seekTo(Duration p) => controller.seekTo(p);
  @override void setSpeed(double s) => controller.setPlaybackSpeed(s);
  @override void setVolume(double v) =>
      controller.setVolume((v * 100).toInt());

  @override
  void enterFullScreen() { _isFullScreen = true;  _notifyExtra(); }

  @override
  void exitFullScreen()  { _isFullScreen = false; _notifyExtra(); }

  void _notifyExtra() {
    for (final cb in List<VoidCallback>.from(_extra)) cb();
  }

  @override
  void addListener(VoidCallback l) {
    _extra.add(l);
    controller.addListener(l);
  }

  @override
  void removeListener(VoidCallback l) {
    _extra.remove(l);
    controller.removeListener(l);
  }

  /// Call in VideoPlayerScreen.dispose() to clean up all listeners.
  void dispose() {
    for (final cb in List<VoidCallback>.from(_extra)) {
      controller.removeListener(cb);
    }
    _extra.clear();
  }
}
