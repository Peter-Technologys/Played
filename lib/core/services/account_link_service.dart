import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import 'auth_service.dart';
import 'http_client.dart';

String get _kAuthBase => '${Environment.workerUrl}/auth';

class AccountLinkService {
  AccountLinkService._();
  static final AccountLinkService instance = AccountLinkService._();

  http.Client get _client => AppHttpClient.instance.client;
  static const Duration _timeout = Duration(seconds: 15);

  Future<AuthResult> linkGoogle(String idToken) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) {
      return const AuthResult(
        ok: false,
        error: 'Sign in to the Otya account you want to keep first.',
      );
    }

    try {
      final response = await _client.post(
        Uri.parse('$_kAuthBase/google/link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'id_token': idToken}),
      ).timeout(_timeout);
      return _profileResult(
        response,
        fallback: 'Google could not be connected to this Otya account.',
      );
    } catch (error) {
      debugPrint('[AccountLink] Google link failed: ${error.runtimeType}');
      return const AuthResult(
        ok: false,
        error: 'Google could not be connected right now. Check your connection and try again.',
      );
    }
  }

  Future<AuthResult> addPrimaryEmail(String email) async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) {
      return const AuthResult(ok: false, error: 'Sign in to Otya first.');
    }

    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      return const AuthResult(ok: false, error: 'Enter a valid email address.');
    }

    try {
      final response = await _client.patch(
        Uri.parse('$_kAuthBase/account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': normalized}),
      ).timeout(_timeout);
      return _profileResult(
        response,
        fallback: 'That email could not be added to this Otya account.',
      );
    } catch (error) {
      debugPrint('[AccountLink] Add email failed: ${error.runtimeType}');
      return const AuthResult(
        ok: false,
        error: 'Otya could not add that email right now. Check your connection and try again.',
      );
    }
  }

  AuthResult _profileResult(http.Response response, {required String fallback}) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return AuthResult(ok: false, error: fallback);
      }
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['ok'] == true) {
        final userJson = decoded['user'];
        final user = userJson is Map<String, dynamic>
            ? UserProfile.fromJson(userJson)
            : null;
        return AuthResult(ok: true, user: user);
      }
      final error = decoded['error'];
      final code = decoded['code'];
      return AuthResult(
        ok: false,
        error: error is String && error.trim().isNotEmpty ? error : fallback,
        errorCode: code is String ? code : null,
      );
    } catch (error) {
      debugPrint('[AccountLink] Invalid response: ${error.runtimeType}');
      return AuthResult(ok: false, error: fallback);
    }
  }
}
