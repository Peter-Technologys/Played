import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appwrite_service.dart';

/// Streams the current Appwrite user (null = not signed in).
final authUserProvider = StreamProvider<models.User?>((ref) async* {
  // Emit current user on startup, then re-emit on sign-in/out events.
  yield await AppwriteService.instance.getCurrentUser();
});

/// True when signed in with Google via Appwrite OAuth.
final isGoogleSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// The signed-in user's display name, or null.
final displayNameProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.name,
    orElse: () => null,
  );
});

/// The signed-in user's photo URL — Appwrite does not expose this directly.
/// Returns null; use displayName initial as avatar fallback.
final photoUrlProvider = Provider<String?>((ref) => null);
