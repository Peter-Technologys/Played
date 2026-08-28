import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_control_service.dart';

/// Keeps small remote-controlled discovery badges (for example NEW) local to
/// the device. The server decides which feature/version is worth surfacing;
/// the device decides whether this user has already opened that version.
class FeatureDiscoveryService extends ChangeNotifier {
  FeatureDiscoveryService._();
  static final FeatureDiscoveryService instance = FeatureDiscoveryService._();

  static const _seenPrefix = 'otya_feature_badge_seen_';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Map<String, dynamic>? badgeFor(String featureKey) {
    final raw = RemoteControlService.instance.config['featureBadges'];
    if (raw is! Map) return null;
    final item = raw[featureKey];
    if (item is! Map || item['enabled'] == false) return null;
    final version = item['version']?.toString().trim() ?? '';
    if (version.isEmpty) return null;
    return item.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<bool> shouldShow(String featureKey) async {
    await init();
    final badge = badgeFor(featureKey);
    if (badge == null) return false;
    final version = badge['version']?.toString() ?? '';
    return _prefs?.getBool('$_seenPrefix$featureKey:$version') != true;
  }

  String labelFor(String featureKey) {
    final label = badgeFor(featureKey)?['label']?.toString().trim();
    return (label == null || label.isEmpty) ? 'NEW' : label;
  }

  Future<void> markOpened(String featureKey) async {
    await init();
    final badge = badgeFor(featureKey);
    if (badge == null) return;
    final version = badge['version']?.toString() ?? '';
    if (version.isEmpty) return;
    await _prefs?.setBool('$_seenPrefix$featureKey:$version', true);
    notifyListeners();
  }
}
