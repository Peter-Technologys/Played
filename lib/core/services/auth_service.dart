import 'package:flutter/foundation.dart';

/// Stub auth service — Firebase removed, Played is fully offline.
/// Kept so any remaining call sites compile without changes.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Stream of auth state — always emits null (no remote auth).
  Stream<Object?> get authStateChanges => const Stream.empty();

  /// No-op — no remote auth needed for an offline media player.
  Future<void> signInAnonymouslyIfNeeded() async {
    debugPrint('[AuthService] Offline mode — no auth required.');
  }

  /// No-op sign out.
  Future<void> signOut() async {
    debugPrint('[AuthService] Offline mode — no sign out needed.');
  }
}
