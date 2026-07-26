import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthState {
  final String? userId;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const _AuthState({this.userId, this.displayName, this.email, this.photoUrl});

  bool get isSignedIn => userId != null && userId!.isNotEmpty;
}

class AuthNotifier extends StateNotifier<_AuthState> {
  AuthNotifier() : super(const _AuthState()) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Use the same keys as AuthService so both systems stay in sync.
    state = _AuthState(
      userId:      prefs.getString('otya_user_id'),
      displayName: prefs.getString('otya_user_name'),
      email:       prefs.getString('otya_user_email'),
      photoUrl:    prefs.getString('otya_user_avatar'),
    );
  }

  Future<void> signIn({required String userId, required String displayName, String? email, String? photoUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    // Use the same keys as AuthService so both systems stay in sync.
    await prefs.setString('otya_user_id', userId);
    await prefs.setString('otya_user_name', displayName);
    if (email != null) await prefs.setString('otya_user_email', email);
    if (photoUrl != null) await prefs.setString('otya_user_avatar', photoUrl);
    state = _AuthState(userId: userId, displayName: displayName, email: email, photoUrl: photoUrl);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    // Use the same keys as AuthService so both systems stay in sync.
    await prefs.remove('otya_user_id');
    await prefs.remove('otya_user_name');
    await prefs.remove('otya_user_email');
    await prefs.remove('otya_user_avatar');
    state = const _AuthState();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, _AuthState>((_) => AuthNotifier());

final isSignedInProvider   = Provider<bool>((ref) => ref.watch(authNotifierProvider).isSignedIn);
final displayNameProvider  = Provider<String?>((ref) { final n = ref.watch(authNotifierProvider).displayName; return (n?.isNotEmpty == true) ? n : null; });
final userEmailProvider    = Provider<String?>((ref) { final e = ref.watch(authNotifierProvider).email; return (e?.isNotEmpty == true) ? e : null; });
final photoUrlProvider     = Provider<String?>((ref) { final u = ref.watch(authNotifierProvider).photoUrl; return (u?.isNotEmpty == true) ? u : null; });


