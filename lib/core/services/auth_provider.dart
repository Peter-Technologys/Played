import 'dart:async';
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

/// STABILITY 1: Fixed auth change stream that does NOT leak _AuthCompleter
/// instances. The original while(true) loop added a new listener on every
/// iteration without ever removing the old one, causing the listener list
/// to grow unboundedly across sign-in/sign-out cycles.
///
/// Fix: use a single persistent callback that resets a shared completer
/// after each completion, and remove the callback when the stream is done.
Stream<void> _authChangeStream() async* {
  // Single completer shared across all iterations.
  var completer = _AuthCompleter();

  // Single persistent callback — registered once, never duplicated.
  void callback() => completer.complete();
  AppwriteService.instance.addAuthListener(callback);

  try {
    while (true) {
      await completer.future;
      yield null;
      // Reset for the next auth event before looping.
      completer = _AuthCompleter();
    }
  } finally {
    // STABILITY 1: Remove the listener when the stream subscription is
    // cancelled (e.g. provider disposed) to prevent a dangling reference.
    // AppwriteService.removeAuthListener is added below.
    AppwriteService.instance.removeAuthListener(callback);
  }
}

class _AuthCompleter {
  final _completer = Completer<void>();
  Future<void> get future => _completer.future;
  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
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


