import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  final String? userId;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const AuthState({
    this.userId,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  bool get isSignedIn => userId != null && userId!.isNotEmpty;

  AuthState copyWith({
    String? userId,
    String? displayName,
    String? email,
    String? photoUrl,
  }) =>
      AuthState(
        userId:      userId      ?? this.userId,
        displayName: displayName ?? this.displayName,
        email:       email       ?? this.email,
        photoUrl:    photoUrl    ?? this.photoUrl,
      );
}

// ── Notifier (Riverpod 2) ─────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _load();
    return const AuthState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AuthState(
      userId:      prefs.getString('otya_user_id'),
      displayName: prefs.getString('otya_user_name'),
      email:       prefs.getString('otya_user_email'),
      photoUrl:    prefs.getString('otya_user_avatar'),
    );
  }

  Future<void> signIn({
    required String userId,
    required String displayName,
    String? email,
    String? photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('otya_user_id', userId);
    await prefs.setString('otya_user_name', displayName);
    if (email    != null) await prefs.setString('otya_user_email',  email);
    if (photoUrl != null) await prefs.setString('otya_user_avatar', photoUrl);
    state = AuthState(
      userId:      userId,
      displayName: displayName,
      email:       email,
      photoUrl:    photoUrl,
    );
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('otya_user_id');
    await prefs.remove('otya_user_name');
    await prefs.remove('otya_user_email');
    await prefs.remove('otya_user_avatar');
    state = const AuthState();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final isSignedInProvider =
    Provider<bool>((ref) => ref.watch(authNotifierProvider).isSignedIn);

final displayNameProvider = Provider<String?>((ref) {
  final n = ref.watch(authNotifierProvider).displayName;
  return (n?.isNotEmpty == true) ? n : null;
});

final userEmailProvider = Provider<String?>((ref) {
  final e = ref.watch(authNotifierProvider).email;
  return (e?.isNotEmpty == true) ? e : null;
});

final photoUrlProvider = Provider<String?>((ref) {
  final u = ref.watch(authNotifierProvider).photoUrl;
  return (u?.isNotEmpty == true) ? u : null;
});
