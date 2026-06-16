import 'package:flutter/foundation.dart';
import 'appwrite_service.dart';

/// Auth service — delegates to AppwriteService.
/// Kept as a thin wrapper so call sites in settings_screen.dart
/// don't need to import AppwriteService directly.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Stream of auth state — always emits null (use authUserProvider instead).
  Stream<Object?> get authStateChanges => const Stream.empty();

  /// Creates an anonymous Appwrite session if none exists.
  Future<void> signInAnonymouslyIfNeeded() async {
    await AppwriteService.instance.signInAnonymouslyIfNeeded();
  }

  /// Signs out of the current Appwrite session.
  Future<void> signOut() async {
    try {
      await AppwriteService.instance.signOut();
      debugPrint('[AuthService] Signed out of Appwrite.');
    } catch (e) {
      debugPrint('[AuthService] Sign out failed: $e');
    }
  }
}
