import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Real-time directory watcher using Directory.watch() (inotify on Android).
/// Events are debounced 300 ms to prevent rapid-fire rebuilds.
class StorageWatcherService {
  final _ctrl = StreamController<FileSystemEvent>.broadcast();
  final List<StreamSubscription<FileSystemEvent>> _subs = [];
  // Per-path debounce timers so events from different directories
  // don't cancel each other's debounce window.
  final Map<String, Timer> _debounces = {};
  // Tracks which paths have an active watcher subscription.
  // Using a dedicated set rather than _debounces (which is cleared after each
  // timer fires) ensures we never register duplicate subscriptions.
  final Set<String> _watchedPaths = {};

  Stream<FileSystemEvent> get events => _ctrl.stream;

  void watch(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;
    // Don't register the same path twice.
    if (_watchedPaths.contains(dirPath)) return;
    _watchedPaths.add(dirPath);
    try {
      final sub = dir.watch(events: FileSystemEvent.all, recursive: true).listen(
        (event) {
          _debounces[dirPath]?.cancel();
          _debounces[dirPath] = Timer(const Duration(milliseconds: 300), () {
            _debounces.remove(dirPath);
            if (!_ctrl.isClosed) _ctrl.add(event);
          });
        },
        onError: (Object e) => debugPrint('[Watcher] $dirPath: $e'),
        cancelOnError: false,
      );
      _subs.add(sub);
    } catch (e) {
      _watchedPaths.remove(dirPath); // remove on failure so watch() can be retried
      debugPrint('[Watcher] Cannot watch $dirPath: $e');
    }
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
    for (final t in _debounces.values) t.cancel();
    _debounces.clear();
    for (final s in _subs) await s.cancel();
    _subs.clear();
    _watchedPaths.clear();
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
