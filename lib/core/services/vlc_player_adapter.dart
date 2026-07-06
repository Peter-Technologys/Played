// VlcPlayerAdapter — bridges VlcPlayerController to OtyaVideoPanel.
// Drop this into VideoPlayerScreen and pass it to OtyaVideoPanel.

import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'fplayer_panel.dart';

class VlcPlayerAdapter implements VideoPlayerAdapter {
  final VlcPlayerController controller;
  bool _isFullScreen = false;

  VlcPlayerAdapter(this.controller);

  @override bool get isPlaying    => controller.value.isPlaying;
  @override bool get isFullScreen => _isFullScreen;
  @override Duration get position => controller.value.position;
  @override Duration get duration => controller.value.duration;
  @override Duration get bufferedPosition {
    // VLC exposes buffering as a percentage (0–100); convert to Duration.
    final pct = controller.value.bufferPercent / 100.0;
    return Duration(
        milliseconds: (controller.value.duration.inMilliseconds * pct).toInt());
  }
  @override double get speed => controller.value.playbackSpeed;

  @override void play()   => controller.play();
  @override void pause()  => controller.pause();
  @override void seekTo(Duration p) => controller.seekTo(p);
  @override void setSpeed(double s) => controller.setPlaybackSpeed(s);
  @override void setVolume(double v) =>
      controller.setVolume((v * 100).toInt());

  @override
  void enterFullScreen() {
    _isFullScreen = true;
    // Notify listeners so the panel rebuilds
    for (final cb in List<void Function()>.from(_listeners)) cb();
  }

  @override
  void exitFullScreen() {
    _isFullScreen = false;
    for (final cb in List<void Function()>.from(_listeners)) cb();
  }

  final List<void Function()> _listeners = [];

  @override
  void addListener(void Function() listener) {
    _listeners.add(listener);
    controller.addListener(listener);
  }

  @override
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
    controller.removeListener(listener);
  }
}
