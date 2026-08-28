import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import 'auth_service.dart';
import 'http_client.dart';

class OtyaAiModel {
  final String id;
  final String name;
  final String provider;
  final String tier;
  final String description;
  final bool guest;

  const OtyaAiModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.tier,
    required this.description,
    required this.guest,
  });

  factory OtyaAiModel.fromJson(Map<String, dynamic> json) => OtyaAiModel(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? json['id'] ?? 'OTYA AI'}',
        provider: '${json['provider'] ?? 'Cloudflare'}',
        tier: '${json['tier'] ?? 'standard'}',
        description: '${json['description'] ?? ''}',
        guest: json['guest'] == true,
      );
}

class OtyaAiQuota {
  final int limit;
  final int used;
  final int remaining;

  const OtyaAiQuota({
    required this.limit,
    required this.used,
    required this.remaining,
  });

  factory OtyaAiQuota.fromJson(Map<String, dynamic> json) => OtyaAiQuota(
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        used: (json['used'] as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      );
}

class OtyaAiMessage {
  final String role;
  final String content;

  const OtyaAiMessage({required this.role, required this.content});

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory OtyaAiMessage.fromJson(Map<String, dynamic> json) => OtyaAiMessage(
        role: '${json['role'] ?? 'assistant'}',
        content: '${json['content'] ?? ''}',
      );
}

class OtyaAiConversation {
  final String id;
  final String title;
  final String? createdAt;
  final String? updatedAt;
  final List<OtyaAiMessage> messages;

  const OtyaAiConversation({
    required this.id,
    required this.title,
    this.createdAt,
    this.updatedAt,
    this.messages = const [],
  });

  factory OtyaAiConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return OtyaAiConversation(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'New chat'}',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((row) => OtyaAiMessage.fromJson(
                    row.map((key, value) => MapEntry('$key', value)),
                  ))
              .where((message) => message.content.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

class OtyaAiCapabilities {
  final List<OtyaAiModel> models;
  final String defaultModel;
  final String guestModel;
  final OtyaAiQuota? quota;

  const OtyaAiCapabilities({
    required this.models,
    required this.defaultModel,
    required this.guestModel,
    this.quota,
  });
}

class OtyaAiReply {
  final String answer;
  final String? conversationId;
  final bool persisted;
  final OtyaAiQuota? quota;

  const OtyaAiReply({
    required this.answer,
    this.conversationId,
    required this.persisted,
    this.quota,
  });
}

class OtyaAiException implements Exception {
  final String message;
  final int? statusCode;

  const OtyaAiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Lightweight client for the standalone OTYA AI service.
///
/// No model weights or inference runtime are bundled in OTYA Player. The app
/// only sends authenticated/guest requests to the OTYA backend gateway, which
/// routes them to the separately deployed `otya-ai` service.
class OtyaAiService {
  OtyaAiService._();
  static final OtyaAiService instance = OtyaAiService._();

  static const _guestKey = 'otya_ai_guest_id';
  static const _modelKey = 'otya_ai_model';
  static const _conversationKey = 'otya_ai_conversation_id';
  static const _timeout = Duration(seconds: 40);

  http.Client get _client => AppHttpClient.instance.client;
  Uri get _chatUri => Uri.parse('${Environment.workerUrl}/api/ai/chat');

  Future<String> guestId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestKey);
    if (existing != null && existing.length >= 16) return existing;
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final generated = '$now-${UniqueKey().hashCode.abs().toRadixString(36)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    await prefs.setString(_guestKey, generated);
    return generated;
  }

  Future<String?> selectedModel() async =>
      (await SharedPreferences.getInstance()).getString(_modelKey);

  Future<void> setSelectedModel(String model) async {
    await (await SharedPreferences.getInstance()).setString(_modelKey, model);
  }

  Future<String?> lastConversationId() async =>
      (await SharedPreferences.getInstance()).getString(_conversationKey);

  Future<void> setLastConversationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_conversationKey);
    } else {
      await prefs.setString(_conversationKey, id);
    }
  }

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final token = await AuthService.instance.getValidToken();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> isSignedIn() => AuthService.instance.checkIsLoggedIn();

  Future<OtyaAiCapabilities> capabilities() async {
    final guest = await guestId();
    final uri = _chatUri.replace(queryParameters: {
      'models': '1',
      'guest_id': guest,
    });
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OtyaAiException(
        _errorFrom(data, 'OTYA AI is unavailable.'),
        statusCode: response.statusCode,
      );
    }
    final models = data['models'] is List
        ? (data['models'] as List)
            .whereType<Map>()
            .map((row) => OtyaAiModel.fromJson(
                  row.map((key, value) => MapEntry('$key', value)),
                ))
            .where((model) => model.id.isNotEmpty)
            .toList()
        : <OtyaAiModel>[];
    return OtyaAiCapabilities(
      models: models,
      defaultModel: '${data['default_model'] ?? 'otya-smart'}',
      guestModel: '${data['guest_model'] ?? 'llama-fast'}',
      quota: data['quota'] is Map
          ? OtyaAiQuota.fromJson(
              (data['quota'] as Map).map((key, value) => MapEntry('$key', value)),
            )
          : null,
    );
  }

  Future<List<OtyaAiConversation>> listConversations() async {
    if (!await isSignedIn()) return const [];
    final uri = _chatUri.replace(queryParameters: {'list': '1'});
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OtyaAiException(
        _errorFrom(data, 'Could not load AI conversations.'),
        statusCode: response.statusCode,
      );
    }
    final rows = data['conversations'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => OtyaAiConversation.fromJson(
              row.map((key, value) => MapEntry('$key', value)),
            ))
        .where((conversation) => conversation.id.isNotEmpty)
        .toList();
  }

  Future<OtyaAiConversation?> getConversation(String id) async {
    if (!await isSignedIn()) return null;
    final uri = _chatUri.replace(queryParameters: {'conversation_id': id});
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OtyaAiException(
        _errorFrom(data, 'Could not restore this conversation.'),
        statusCode: response.statusCode,
      );
    }
    final raw = data['conversation'];
    if (raw is! Map) return null;
    return OtyaAiConversation.fromJson(
      raw.map((key, value) => MapEntry('$key', value)),
    );
  }

  Future<OtyaAiReply> send({
    required String message,
    String? conversationId,
    String? model,
    bool newChat = false,
    List<OtyaAiMessage> guestHistory = const [],
  }) async {
    final signedIn = await isSignedIn();
    final guest = await guestId();
    final body = <String, dynamic>{
      'message': message,
      'guest_id': guest,
      if (signedIn && conversationId != null) 'conversation_id': conversationId,
      if (signedIn && newChat) 'new_chat': true,
      if (signedIn && model != null && model.isNotEmpty) 'model': model,
      if (!signedIn)
        'history': guestHistory
            .take(20)
            .map((entry) => entry.toJson())
            .toList(growable: false),
    };

    try {
      final response = await _client
          .post(
            _chatUri,
            headers: await _headers(jsonBody: true),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OtyaAiException(
          _errorFrom(data, 'OTYA AI could not answer right now.'),
          statusCode: response.statusCode,
        );
      }
      final answer = '${data['answer'] ?? ''}'.trim();
      return OtyaAiReply(
        answer: answer.isEmpty ? 'I could not answer that.' : answer,
        conversationId: data['conversation_id'] as String?,
        persisted: data['persisted'] == true,
        quota: data['quota'] is Map
            ? OtyaAiQuota.fromJson(
                (data['quota'] as Map)
                    .map((key, value) => MapEntry('$key', value)),
              )
            : null,
      );
    } on OtyaAiException {
      rethrow;
    } catch (error) {
      debugPrint('[OtyaAiService] request failed: ${error.runtimeType}');
      throw const OtyaAiException(
        'Could not reach OTYA AI. Check your connection and try again.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _errorFrom(Map<String, dynamic> data, String fallback) {
    final raw = data['error'];
    return raw is String && raw.trim().isNotEmpty ? raw.trim() : fallback;
  }
}
