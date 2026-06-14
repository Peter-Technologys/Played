import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Syncs Pro expiry to Firestore — ONLINE ONLY.
///
/// This service is only called after Firebase has initialised in the
/// background. Every method is fully offline-safe:
///   - fetchProExpiry() reads from local Firestore cache first (instant,
///     works offline), then falls back to a network fetch with a 4-second
///     timeout so it never hangs the UI thread or triggers an ANR.
///   - saveProExpiry() / clearProExpiry() are fire-and-forget with
///     try/catch — offline failures are silently ignored.
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

  /// Cache-first fetch — never blocks startup.
  ///
  /// 1. Try Firestore local cache (instant, works offline).
  /// 2. On cache miss, attempt network with 4-second timeout.
  /// 3. Return 0 on any failure — SharedPreferences is the source of
  ///    truth for the current session.
  Future<int> fetchProExpiry() async {
    final doc = _proDoc;
    if (doc == null) return 0;

    // 1. Local cache — instant even offline
    try {
      final cached = await doc.get(GetOptions(source: Source.cache));
      if (cached.exists) {
        return (cached.data()?['expiry_ms'] as int?) ?? 0;
      }
    } catch (_) {
      // Cache miss on first install — fall through to network
    }

    // 2. Network with timeout — prevents ANR on slow connections
    try {
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
