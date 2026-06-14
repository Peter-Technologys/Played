import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

/// Streams the current Firebase [User] (null = not signed in).
final authUserProvider = StreamProvider<User?>((ref) {
  return AuthService.instance.authStateChanges;
});

/// Convenience provider — true when signed in with Google.
final isGoogleSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null &&
        user.providerData
            .any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID),
    orElse: () => false,
  );
});

/// The signed-in user's display name, or null.
final displayNameProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.displayName,
    orElse: () => null,
  );
});

/// The signed-in user's photo URL, or null.
final photoUrlProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.photoURL,
    orElse: () => null,
  );
});
