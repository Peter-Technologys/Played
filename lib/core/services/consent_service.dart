import 'dart:convert';

import '../config/environment.dart';
import 'auth_service.dart';
import 'http_client.dart';

class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  Future<bool> setMarketingConsent(bool enabled) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) return false;
    try {
      final response = await AppHttpClient.instance.client.patch(
        Uri.parse('${Environment.workerUrl}/auth/consent'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'marketing_consent': enabled}),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
