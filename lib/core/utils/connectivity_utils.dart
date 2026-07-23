import 'package:connectivity_plus/connectivity_plus.dart';

/// Returns true when the device has at least one active network connection.
///
/// Used by [CloudflareService] and [ProService] to skip network calls when
/// offline, avoiding 12-second timeout hangs.
///
/// Returns `true` (assume online) if the connectivity check itself fails,
/// so callers can attempt the request and handle the resulting error normally.
Future<bool> isOnline() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  } catch (_) {
    return true; // assume online if the check itself fails
  }
}
