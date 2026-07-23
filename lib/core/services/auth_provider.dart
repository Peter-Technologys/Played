import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth state based on SharedPreferences (userId stored by Google Sign-In).
/// Appwrite has been removed — auth is now handled by Google Sign-In only,
/// with the userId persisted under 'appwrite_user_id' for Cloudflare calls.

class _AuthState {
  final String? userId;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const _AuthState({
    this.userId,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  bool get isSignedIn => userId != null && userId!.isNotEmpty;
}

Future<_AuthState> _loadAuthState() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('appwrite_user_id');
  final displayName = prefs.getString('auth_display_name');
  final email = prefs.getString('auth_email');
  final photoUrl = prefs.getString('auth_photo_url');
  return _AuthState(
    userId: userId,
    displayName: displayName,
    email: email,
    photoUrl: photoUrl,
  );
}

/// Provides the current auth state loaded from SharedPreferences.
final authStateProvider = FutureProvider<_AuthState>((_) => _loadAuthState());

/// True when a user is signed in (userId is non-empty in SharedPreferences).
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
    data: (state) => state.isSignedIn,
    orElse: () => false,
  );
});

/// The signed-in user's display name, or null.
final displayNameProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
    data: (state) =>
        state.displayName?.isNotEmpty == true ? state.displayName : null,
    orElse: () => null,
  );
});

/// The signed-in user's email, or null.
final userEmailProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
    data: (state) => state.email?.isNotEmpty == true ? state.email : null,
    orElse: () => null,
  );
});

/// Google profile photo URL, or null.
final photoUrlProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
    data: (state) => state.photoUrl?.isNotEmpty == true ? state.photoUrl : null,
    orElse: () => null,
  );
});


