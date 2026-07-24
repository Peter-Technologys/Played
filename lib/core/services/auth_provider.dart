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
    state = _AuthState(
      userId:      prefs.getString('appwrite_user_id'),
      displayName: prefs.getString('auth_display_name'),
      email:       prefs.getString('auth_email'),
      photoUrl:    prefs.getString('auth_photo_url'),
    );
  }

  Future<void> signIn({required String userId, required String displayName, String? email, String? photoUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appwrite_user_id', userId);
    await prefs.setString('auth_display_name', displayName);
    if (email != null) await prefs.setString('auth_email', email);
    if (photoUrl != null) await prefs.setString('auth_photo_url', photoUrl);
    state = _AuthState(userId: userId, displayName: displayName, email: email, photoUrl: photoUrl);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('appwrite_user_id');
    await prefs.remove('auth_display_name');
    await prefs.remove('auth_email');
    await prefs.remove('auth_photo_url');
    state = const _AuthState();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, _AuthState>((_) => AuthNotifier());

final isSignedInProvider   = Provider<bool>((ref) => ref.watch(authNotifierProvider).isSignedIn);
final displayNameProvider  = Provider<String?>((ref) { final n = ref.watch(authNotifierProvider).displayName; return (n?.isNotEmpty == true) ? n : null; });
final userEmailProvider    = Provider<String?>((ref) { final e = ref.watch(authNotifierProvider).email; return (e?.isNotEmpty == true) ? e : null; });
final photoUrlProvider     = Provider<String?>((ref) { final u = ref.watch(authNotifierProvider).photoUrl; return (u?.isNotEmpty == true) ? u : null; });


