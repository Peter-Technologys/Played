import 'package:flutter/foundation.dart';
import 'appwrite_service.dart';

/// Thin wrapper kept for call-site compatibility.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<void> signOut() async {
    try {
      await AppwriteService.instance.signOut();
    } catch (e) {
      debugPrint('[AuthService] Sign out failed: $e');
    }
  }
}
