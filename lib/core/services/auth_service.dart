import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles Firebase Auth — anonymous by default, upgradeable to Google.
///
/// Flow:
///   1. App opens → silent anonymous sign-in (user never sees this).
///   2. User optionally taps "Sign in with Google" in Settings.
///   3. Anonymous account is upgraded → UID stays the same → Pro + data preserved.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// The currently signed-in user, or null if not yet initialised.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether the current user signed in with Google (not anonymous).
  bool get isSignedInWithGoogle {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData
        .any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID);
  }

  /// Silently signs in anonymously if no user exists yet.
  /// Called once at app startup — the user never sees a prompt.
  Future<void> signInAnonymouslyIfNeeded() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      // Offline or Firebase unavailable — app continues without auth.
      debugPrint('[AuthService] Anonymous sign-in failed: $e');
    }
  }

  /// Launches the Google Sign-In flow and upgrades the anonymous account.
  /// Returns the signed-in [User] on success, or null if cancelled / failed.
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result;
      final current = _auth.currentUser;

      if (current != null && current.isAnonymous) {
        // Upgrade anonymous → Google (UID stays the same)
        result = await current.linkWithCredential(credential);
      } else {
        result = await _auth.signInWithCredential(credential);
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // Google account already linked to another UID — sign in directly
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final result = await _auth.signInWithCredential(credential);
        return result.user;
      }
      debugPrint('[AuthService] Google sign-in error: $e');
      return null;
    } catch (e) {
      debugPrint('[AuthService] Google sign-in error: $e');
      return null;
    }
  }

  /// Signs out and immediately creates a new anonymous session.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await signInAnonymouslyIfNeeded();
  }
}
