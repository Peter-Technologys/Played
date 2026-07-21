import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appwrite_service.dart';

/// Streams the current Appwrite user.
/// Re-emits whenever sign-in or sign-out happens.
final authUserProvider = StreamProvider<models.User?>((ref) async* {
  yield await AppwriteService.instance.getCurrentUser();
  await for (final _ in _authChangeStream()) {
    yield await AppwriteService.instance.getCurrentUser();
  }
});

Stream<void> _authChangeStream() async* {
  while (true) {
    final completer = _AuthCompleter();
    AppwriteService.instance.addAuthListener(completer.complete);
    await completer.future;
    yield null;
  }
}

class _AuthCompleter {
  bool _done = false;

  Future<void> get future async {
    while (!_done) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void complete() => _done = true;
}

/// True when a real user is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authUserProvider).maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// The signed-in user's display name, or null.
final displayNameProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider).maybeWhen(
    data: (user) => user?.name.isNotEmpty == true ? user!.name : null,
    orElse: () => null,
  );
});

/// The signed-in user's email, or null.
final userEmailProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider).maybeWhen(
    data: (user) => user?.email.isNotEmpty == true ? user!.email : null,
    orElse: () => null,
  );
});

/// Google profile photo URL.
/// Appwrite stores it in user prefs after OAuth under key 'avatarUrl'.
/// Falls back to the Appwrite avatar API which generates an initials avatar.
final photoUrlProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider).maybeWhen(
    data: (user) {
      if (user == null) return null;
      // Check prefs for Google avatar stored after OAuth
      final prefs = user.prefs.data;
      final avatar = prefs['avatarUrl'] as String?;
      if (avatar != null && avatar.isNotEmpty) return avatar;
      // Fallback: Appwrite initials avatar
      if (user.name.isNotEmpty) {
        final encoded = Uri.encodeComponent(user.name);
        return 'https://nyc.cloud.appwrite.io/v1/avatars/initials?name=$encoded&project=6a3011f1003b1a6cc74d';
      }
      return null;
    },
    orElse: () => null,
  );
});

// Compatibility aliases
final isGoogleSignedInProvider = isSignedInProvider;
