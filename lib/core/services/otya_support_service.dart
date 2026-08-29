import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import 'auth_service.dart';
import 'http_client.dart';

class OtyaSupportReply {
  final String answer;
  final bool inScope;
  final bool handoffAvailable;

  const OtyaSupportReply({
    required this.answer,
    required this.inScope,
    required this.handoffAvailable,
  });
}

class OtyaSupportTicket {
  final String id;

  const OtyaSupportTicket(this.id);
}

class OtyaSupportService {
  OtyaSupportService._();
  static final OtyaSupportService instance = OtyaSupportService._();

  static const _guestKey = 'otya_support_guest_id_v1';
  static const _timeout = Duration(seconds: 35);

  http.Client get _client => AppHttpClient.instance.client;
  Uri get _uri => Uri.parse('${Environment.workerUrl}/api/ai/chat');

  Future<String> _guestId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestKey);
    if (existing != null && existing.length >= 16) return existing;
    final random = Random.secure();
    final value = base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    await prefs.setString(_guestKey, value);
    return value;
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getValidToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<OtyaSupportReply> ask(String question) async {
    final response = await _client
        .post(
          _uri,
          headers: await _headers(),
          body: jsonEncode({
            'message': question.trim(),
            'guest_id': await _guestId(),
            'surface': 'android-support',
          }),
        )
        .timeout(_timeout);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_error(data, 'Ask OTYA is unavailable right now.'));
    }
    return OtyaSupportReply(
      answer: '${data['answer'] ?? ''}'.trim().isEmpty
          ? 'I could not answer that right now.'
          : '${data['answer']}'.trim(),
      inScope: data['scope'] != 'outside-otya',
      handoffAvailable: data['handoff_available'] == true,
    );
  }

  Future<OtyaSupportTicket> handoff({
    required String question,
    required String email,
  }) async {
    final response = await _client
        .post(
          _uri,
          headers: await _headers(),
          body: jsonEncode({
            'message': question.trim(),
            'email': email.trim(),
            'guest_id': await _guestId(),
            'surface': 'android-support',
            'handoff': true,
          }),
        )
        .timeout(_timeout);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_error(data, 'Could not contact OTYA support.'));
    }
    return OtyaSupportTicket('${data['ticket_id'] ?? 'OTYA'}');
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _error(Map<String, dynamic> data, String fallback) {
    final value = data['error'];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }
}
