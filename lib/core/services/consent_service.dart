import 'dart:convert';

import '../config/environment.dart';
import 'auth_service.dart';
import 'http_client.dart';

class ConsentState {
  final bool termsAccepted;
  final String? termsVersion;
  final bool privacyAccepted;
  final String? privacyVersion;
  final bool marketingConsent;
  final String currentTermsVersion;
  final String currentPrivacyVersion;

  const ConsentState({
    required this.termsAccepted,
    required this.termsVersion,
    required this.privacyAccepted,
    required this.privacyVersion,
    required this.marketingConsent,
    required this.currentTermsVersion,
    required this.currentPrivacyVersion,
  });

  bool get legalCurrent =>
      termsAccepted &&
      privacyAccepted &&
      termsVersion == currentTermsVersion &&
      privacyVersion == currentPrivacyVersion;
}

class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  Future<ConsentState?> getConsent() async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) return null;
    try {
      final response = await AppHttpClient.instance.client.get(
        Uri.parse('${Environment.workerUrl}/auth/consent'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final raw = decoded['consent'];
      if (raw is! Map<String, dynamic>) return null;
      bool flag(dynamic value) => value == true || value == 1 || value == '1';
      return ConsentState(
        termsAccepted: flag(raw['terms_accepted']),
        termsVersion: raw['terms_version'] as String?,
        privacyAccepted: flag(raw['privacy_accepted']),
        privacyVersion: raw['privacy_version'] as String?,
        marketingConsent: flag(raw['marketing_consent']),
        currentTermsVersion:
            (decoded['terms_version'] as String?) ?? AuthService.termsVersion,
        currentPrivacyVersion:
            (decoded['privacy_version'] as String?) ?? AuthService.privacyVersion,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> setMarketingConsent(bool enabled) async {
    return _patch({'marketing_consent': enabled});
  }

  Future<bool> acceptCurrentLegal({bool? marketingConsent}) async {
    return _patch({
      'terms_accepted': true,
      'terms_version': AuthService.termsVersion,
      'privacy_accepted': true,
      'privacy_version': AuthService.privacyVersion,
      if (marketingConsent != null) 'marketing_consent': marketingConsent,
    });
  }

  Future<bool> _patch(Map<String, dynamic> body) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) return false;
    try {
      final response = await AppHttpClient.instance.client.patch(
        Uri.parse('${Environment.workerUrl}/auth/consent'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
