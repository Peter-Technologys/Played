import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import 'auth_service.dart';

/// Push registration facade. Firebase/FCM SDK integration is intentionally
/// disabled until the native push provider is reintroduced consistently.
/// Stored tokens are re-registered when available; push failures are non-fatal.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _keyFcmToken = 'fcm_token';
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyFcmToken);
      if (token != null && token.isNotEmpty) {
        await _registerWithBackend(token);
      }
      debugPrint('[FcmService] Initialized.');
    } catch (e, st) {
      debugPrint('[FcmService] init error (non-fatal): $e\n$st');
    }
  }

  Future<void> _registerWithBackend(String token) async {
    final accessToken = await AuthService.instance.getValidToken();
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      const path = '/api/push/register';
      final response = await http
          .post(
            Uri.parse('${Environment.workerUrl}$path'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'fcm_token': token}),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('[FcmService] push registration → ${response.statusCode}');
    } catch (e) {
      debugPrint('[FcmService] push registration failed (non-fatal): $e');
    }
  }
}
