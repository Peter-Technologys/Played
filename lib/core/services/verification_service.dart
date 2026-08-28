import 'dart:convert';

import '../config/environment.dart';
import 'auth_service.dart';
import 'http_client.dart';

class VerificationSendResult {
  final bool ok;
  final String message;
  final int? statusCode;

  const VerificationSendResult({
    required this.ok,
    required this.message,
    this.statusCode,
  });
}

/// Sends verification codes while preserving useful, non-sensitive delivery
/// diagnostics for the Account screen.
class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  Future<VerificationSendResult> sendCode() async {
    final token = await AuthService.instance.getValidToken();
    if (token == null) {
      return const VerificationSendResult(
        ok: false,
        message: 'Your session expired. Sign in again before requesting a code.',
        statusCode: 401,
      );
    }

    try {
      final response = await AppHttpClient.instance.client.post(
        Uri.parse('${Environment.workerUrl}/auth/send-verification'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return VerificationSendResult(
          ok: true,
          message: 'Verification code sent to ${AuthService.instance.userEmail ?? 'your email'}.',
          statusCode: response.statusCode,
        );
      }

      String? serverMessage;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final value = decoded['error'] ?? decoded['message'];
          if (value is String && value.trim().isNotEmpty) {
            serverMessage = value.trim();
          }
        }
      } catch (_) {
        // Do not surface or log raw provider/upstream bodies.
      }

      final message = switch (response.statusCode) {
        401 => 'Your session expired. Sign in again and request a new code.',
        429 => 'Too many verification requests. Wait a little before trying again.',
        502 || 503 => 'OTYA email delivery is temporarily unavailable. Please try again shortly.',
        _ => serverMessage ?? 'Could not send the verification code. Please try again.',
      };

      return VerificationSendResult(
        ok: false,
        message: message,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const VerificationSendResult(
        ok: false,
        message: 'Could not reach OTYA right now. Check your connection and try again.',
      );
    }
  }
}
