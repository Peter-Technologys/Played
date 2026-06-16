import 'package:flutter/foundation.dart';

/// Firestore Pro sync service — STUB.
///
/// Firestore requires the following packages which are not yet added:
///   cloud_firestore: ^4.0.0
///   firebase_auth: ^4.0.0
///   firebase_core: ^2.0.0
///
/// Until those are added, all methods are no-ops that return safe defaults.
/// Pro status is managed locally via SharedPreferences (ProService).
class FirestoreProService {
  FirestoreProService._();
  static final FirestoreProService instance = FirestoreProService._();

  /// Saves Pro expiry to Firestore. No-op until Firebase is configured.
  Future<void> saveProExpiry(int expiryMs) async {
    debugPrint('[FirestoreProService] Firestore not configured — skipping save.');
  }

  /// Fetches Pro expiry from Firestore. Returns 0 until Firebase is configured.
  Future<int> fetchProExpiry() async {
    debugPrint('[FirestoreProService] Firestore not configured — returning 0.');
    return 0;
  }

  /// Clears Pro expiry in Firestore. No-op until Firebase is configured.
  Future<void> clearProExpiry() async {
    debugPrint('[FirestoreProService] Firestore not configured — skipping clear.');
  }
}
