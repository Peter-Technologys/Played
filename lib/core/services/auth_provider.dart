import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appwrite_service.dart';

/// Streams the current Appwrite user.
/// Re-emits whenever sign-in or sign-out happens.
final authUserProvider = StreamProvider<models.User?>((ref) async* {
  // Emit current state immediately
  yield await AppwriteService.instance.getCurrentUser();

  // Then re-emit every time auth changes (sign-in / sign-out)
  await for (final _ in _authChangeStream()) {
    yield await AppwriteService.instance.getCurrentUser();
  }
});

Stream<void> _authChangeStream() async* {
  // Backed by the callback list on AppwriteService
  while (true) {
    final completer = _AuthCompleter();
    AppwriteService.instance.addAuthListener(completer.complete);
    await completer.future;
    yield null;
  }
}

class _AuthCompleter {
  bool _done = false;
  void Function()? _resolve;

  Future<void> get future async {
    if (_done) return;
    await Future<void>(() async {
      while (!_done) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
  }

  void complete() {
    _done = true;
    _resolve?.call();
  }
}

/// True when a real (non-anonymous) user is signed in.
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

// Keep old name for settings_screen.dart compatibility
final isGoogleSignedInProvider = isSignedInProvider;
final photoUrlProvider = Provider<String?>((_) => null);
