import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// Tracks locally discovered media that the user has not opened yet.
///
/// Nothing is uploaded. This lets Video/Music show a subtle NEW marker for
/// media received from OTYA Transfer, Bluetooth, WhatsApp, Telegram, browser
/// downloads, Xender/SHAREit folders or any other source discovered by the
/// normal media scanner.
class NewMediaTracker extends ChangeNotifier {
  NewMediaTracker._();
  static final NewMediaTracker instance = NewMediaTracker._();

  static const _knownKey = 'otya_media_known_ids_v1';
  static const _unseenKey = 'otya_media_unseen_ids_v1';
  static const _initializedKey = 'otya_media_seen_baseline_v1';

  final Set<String> _unseen = <String>{};
  SharedPreferences? _prefs;

  Set<String> get unseenIds => Set.unmodifiable(_unseen);
  bool isUnseen(MediaItem item) => _unseen.contains(item.id);
  bool isPathUnseen(String path) => _unseen.contains(Uri.encodeComponent(path));

  Future<void> reconcile(List<MediaItem> items) async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final current = items.map((e) => e.id).toSet();
    final known = _decodeSet(prefs.getString(_knownKey));
    final unseen = _decodeSet(prefs.getString(_unseenKey));

    // First successful scan establishes a baseline so an existing library is
    // not suddenly covered in NEW labels after an app update.
    if (prefs.getBool(_initializedKey) != true) {
      await prefs.setString(_knownKey, jsonEncode(current.toList()));
      await prefs.setString(_unseenKey, '[]');
      await prefs.setBool(_initializedKey, true);
      _unseen.clear();
      notifyListeners();
      return;
    }

    unseen
      ..removeWhere((id) => !current.contains(id))
      ..addAll(current.difference(known));

    await prefs.setString(_knownKey, jsonEncode(current.toList()));
    await prefs.setString(_unseenKey, jsonEncode(unseen.toList()));
    _unseen
      ..clear()
      ..addAll(unseen);
    notifyListeners();
  }

  Future<void> markSeen(MediaItem item) => markSeenId(item.id);

  /// Safe for lower-level player code that only knows the local path.
  /// MediaScannerService uses Uri.encodeComponent(path) as the stable ID, so
  /// this does not need a database lookup or rescan.
  Future<void> markSeenPath(String path) => markSeenId(Uri.encodeComponent(path));

  Future<void> markSeenId(String id) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!_unseen.remove(id)) return;
    await _prefs!.setString(_unseenKey, jsonEncode(_unseen.toList()));
    notifyListeners();
  }

  Future<void> markAllSeen(Iterable<MediaItem> items) async {
    _prefs ??= await SharedPreferences.getInstance();
    var changed = false;
    for (final item in items) {
      changed = _unseen.remove(item.id) || changed;
    }
    if (!changed) return;
    await _prefs!.setString(_unseenKey, jsonEncode(_unseen.toList()));
    notifyListeners();
  }

  static Set<String> _decodeSet(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toSet();
    } catch (_) {}
    return <String>{};
  }
}
