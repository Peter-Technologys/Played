import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Serializes media-load operations so one slow/failing load cannot deadlock
/// subsequent requests.
class LoadingStateManager {
  final Queue<Future<void>> _loadQueue = Queue<Future<void>>();
  bool _isProcessing = false;
  int _generation = 0;

  bool get isLoading => _isProcessing || _loadQueue.isNotEmpty;

  Future<int> enqueue(Future<void> Function() loadFn) async {
    final myGen = ++_generation;
    _loadQueue.add(loadFn());
    debugPrint('[LoadingStateManager] Queued load #$myGen (queue size: ${_loadQueue.length})');
    if (!_isProcessing) {
      unawaited(_processQueue());
    }
    return myGen;
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      while (_loadQueue.isNotEmpty) {
        final loadFuture = _loadQueue.removeFirst();
        try {
          await loadFuture;
        } catch (e) {
          debugPrint('[LoadingStateManager] Load error: $e');
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  void cancelAll() {
    _loadQueue.clear();
    _generation++;
    debugPrint('[LoadingStateManager] Cancelled queued loads');
  }
}
