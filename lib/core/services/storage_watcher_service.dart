import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Real-time directory watcher using Directory.watch() (inotify on Android).
/// Events are debounced 300 ms to prevent rapid-fire rebuilds.
class StorageWatcherService {
  final _ctrl = StreamController<FileSystemEvent>.broadcast();
  final List<StreamSubscription<FileSystemEvent>> _subs = [];
  Timer? _debounce;

  Stream<FileSystemEvent> get events => _ctrl.stream;

  void watch(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;
    try {
      final sub = dir.watch(events: FileSystemEvent.all, recursive: true).listen(
        (event) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () {
            if (!_ctrl.isClosed) _ctrl.add(event);
          });
        },
        onError: (Object e) => debugPrint('[Watcher] $dirPath: $e'),
        cancelOnError: false,
      );
      _subs.add(sub);
    } catch (e) { debugPrint('[Watcher] Cannot watch $dirPath: $e'); }
  }

  void watchAll() {
    const dirs = [
      '/storage/emulated/0/Download', '/storage/emulated/0/Music',
      '/storage/emulated/0/Movies',   '/storage/emulated/0/DCIM',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/Telegram/Telegram Audio',
      '/storage/emulated/0/Telegram/Telegram Video',
    ];
    for (final d in dirs) watch(d);
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    for (final s in _subs) await s.cancel();
    _subs.clear();
    await _ctrl.close();
  }
}
