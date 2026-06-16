import 'package:flutter/foundation.dart';

/// Firestore Pro sync — REMOVED (migrated to Appwrite).
///
/// Pro status is now managed locally via SharedPreferences (ProService).
/// Appwrite sync can be added later via AppwriteService if needed.
/// This stub is kept so ProService compiles without changes.
class FirestoreProService {
  FirestoreProService._();
  static final FirestoreProService instance = FirestoreProService._();

  Future<void> saveProExpiry(int expiryMs) async {
    debugPrint('[ProSync] Appwrite pro sync not yet wired — skipping save.');
  }

  Future<int> fetchProExpiry() async {
    debugPrint('[ProSync] Appwrite pro sync not yet wired — returning 0.');
    return 0;
  }

  Future<void> clearProExpiry() async {
    debugPrint('[ProSync] Appwrite pro sync not yet wired — skipping clear.');
  }
}
