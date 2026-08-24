// lib/core/providers/connectivity_provider.dart
//
// Riverpod providers that expose ConnectivityService to the widget tree.
//
// Usage:
//   // Watch offline state in a widget:
//   final isOffline = ref.watch(isOfflineProvider);
//
//   // React to connectivity changes:
//   ref.listen(isOfflineProvider, (_, isOffline) {
//     if (!isOffline) _flushPendingRequests();
//   });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// StreamProvider that emits `true` when the device is offline, `false` when
/// online. Wraps [ConnectivityService.instance.offlineStream].
///
/// The initial value is derived synchronously from
/// [ConnectivityService.instance.isOffline] so there is no loading state.
final connectivityProvider = StreamProvider<bool>((ref) {
  // Seed with the current synchronous value so the UI never shows a loading
  // spinner — ConnectivityService.init() has already been called in main().
  return ConnectivityService.instance.offlineStream;
});

/// Convenience provider: `true` when offline, `false` when online.
/// Falls back to `false` (assume online) while the stream has not yet emitted.
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
    data: (offline) => offline,
    orElse: () => ConnectivityService.instance.isOffline,
  );
});
