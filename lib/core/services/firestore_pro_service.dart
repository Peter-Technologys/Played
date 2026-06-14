import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Syncs Pro expiry to Firestore so it survives reinstalls and
/// works across multiple devices for the same Google account.
///
/// Document path: users/{uid}/pro/status
class FirestoreProService {
  FirestoreProService._();
  static final FirestoreProService instance = FirestoreProService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _proDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('pro').doc('status');
  }

  /// Saves Pro expiry timestamp to Firestore.
  /// No-op if user is not authenticated.
  Future<void> saveProExpiry(int expiryMs) async {
    final doc = _proDoc;
    if (doc == null) return;
    try {
      await doc.set(
        {'expiry_ms': expiryMs, 'updated_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      // Offline — SharedPreferences fallback still holds the value.
      debugPrint('[FirestoreProService] Save failed (offline?): $e');
    }
  }

  /// Fetches Pro expiry from Firestore.
  /// Returns 0 if not found or offline.
  Future<int> fetchProExpiry() async {
    final doc = _proDoc;
    if (doc == null) return 0;
    try {
      final snap = await doc.get();
      if (!snap.exists) return 0;
      return (snap.data()?['expiry_ms'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[FirestoreProService] Fetch failed (offline?): $e');
      return 0;
    }
  }

  /// Clears Pro from Firestore (e.g. on revoke).
  Future<void> clearProExpiry() async {
    final doc = _proDoc;
    if (doc == null) return;
    try {
      await doc.set(
        {'expiry_ms': 0, 'updated_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
