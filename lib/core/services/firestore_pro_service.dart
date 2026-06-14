import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Syncs Pro expiry to Firestore so it survives reinstalls and
/// works across multiple devices for the same Google account.
///
/// Document path: users/{uid}/pro/status
///
/// IMPORTANT: fetchProExpiry() uses Source.cache first so it never
/// hangs on startup when Firebase Auth is still initialising or the
/// device is offline. A .get() call without a source hint will block
/// until the network times out, which triggers the ANR watchdog.
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
      debugPrint('[FirestoreProService] Save failed (offline?): $e');
    }
  }

  /// Fetches Pro expiry from Firestore.
  ///
  /// Strategy:
  ///   1. Try local Firestore cache first (instant, works offline).
  ///   2. If cache miss, attempt a real network fetch with a 4-second
  ///      timeout so we never block the UI thread.
  ///   3. Return 0 on any failure — SharedPreferences is the source of
  ///      truth for the current session.
  Future<int> fetchProExpiry() async {
    final doc = _proDoc;
    if (doc == null) return 0;
    try {
      // 1. Cache-first — instant even offline
      final cached = await doc.get(GetOptions(source: Source.cache));
      if (cached.exists) {
        return (cached.data()?['expiry_ms'] as int?) ?? 0;
      }
    } catch (_) {
      // Cache miss is normal on first install — fall through to network
    }
    try {
      // 2. Network fetch with timeout — prevents ANR on slow connections
      final snap = await doc
          .get(GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
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
