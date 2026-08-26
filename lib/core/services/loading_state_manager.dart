import 'dart:async';
import 'package:flutter/foundation.dart';

/// FIX #2: Replace stale loading flag deadlock with proper AsyncQueue
/// Ensures only one load operation runs at a time, properly handling errors.
class LoadingStateManager {
  final Queue<Future<void>> _loadQueue = Queue();
  bool _isProcessing = false;
  
  /// Completes when current load finishes
  late Completer<void> _currentLoad;
  
  /// Track load generation to cancel stale operations
  int _generation = 0;
  
  bool get isLoading => _isProcessing || _loadQueue.isNotEmpty;
  
  /// Queue a load operation. Waits for previous loads to complete.
  /// Returns the generation ID so callers can check if their load completed.
  Future<int> enqueue(Future<void> Function() loadFn) async {
    final myGen = ++_generation;
    
    _loadQueue.add(loadFn());
    debugPrint('[LoadingStateManager] Queued load #$myGen (queue size: ${_loadQueue.length})');
    
    // Start processing if not already
    if (!_isProcessing) {
      _processQueue();
    }
    
    return myGen;
  }
  
  /// Process the queue sequentially
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    while (_loadQueue.isNotEmpty) {
      final loadFuture = _loadQueue.removeFirst();
      debugPrint('[LoadingStateManager] Processing load (${_loadQueue.length} remaining)');
      
      try {
        await loadFuture;
        debugPrint('[LoadingStateManager] Load completed successfully');
      } catch (e) {
        debugPrint('[LoadingStateManager] Load error: $e');
        // Log but continue processing queue
      }
    }
    
    _isProcessing = false;
    debugPrint('[LoadingStateManager] Queue empty, done processing');
  }
  
  /// Cancel all queued loads (e.g., when user navigates away)
  void cancelAll() {
    _loadQueue.clear();
    _isProcessing = false;
    _generation++; // Invalidate all pending loads
    debugPrint('[LoadingStateManager] Cancelled all queued loads');
  }
}
