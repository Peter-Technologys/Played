import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

/// Streams the current auth state (always null — offline app).
final authUserProvider = StreamProvider<Object?>((ref) {
  return AuthService.instance.authStateChanges;
});

/// Convenience provider — always false (no Google sign-in in offline mode).
final isGoogleSignedInProvider = Provider<bool>((ref) => false);

/// The signed-in user's display name — always null in offline mode.
final displayNameProvider = Provider<String?>((ref) => null);

/// The signed-in user's photo URL — always null in offline mode.
final photoUrlProvider = Provider<String?>((ref) => null);
