import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import 'auth_service.dart';
import 'firebase_platform_service.dart';
import 'http_client.dart';

class OtyaSupportReply {
  final String answer;
  final bool inScope;
  final bool handoffAvailable;
  final String? modelId;
  final String? modelName;

  const OtyaSupportReply({
    required this.answer,
    required this.inScope,
    required this.handoffAvailable,
    this.modelId,
    this.modelName,
  });
}

class OtyaSupportStreamEvent {
  const OtyaSupportStreamEvent._({
    required this.type,
    this.delta,
    this.modelId,
    this.modelName,
    this.conversationId,
    this.error,
    this.complete = false,
  });

  final String type;
  final String? delta;
  final String? modelId;
  final String? modelName;
  final String? conversationId;
  final String? error;
  final bool complete;

  bool get isDelta => type == 'delta' && delta != null && delta!.isNotEmpty;
  bool get isError => type == 'error';
  bool get isDone => type == 'done';

  factory OtyaSupportStreamEvent.fromJson(Map<String, dynamic> json) =>
      OtyaSupportStreamEvent._(
        type: '${json['type'] ?? ''}',
        delta: json['delta']?.toString(),
        modelId: json['model']?.toString(),
        modelName: json['model_name']?.toString(),
        conversationId: json['conversation_id']?.toString(),
        error: json['error']?.toString(),
        complete: json['complete'] == true,
      );

  factory OtyaSupportStreamEvent.delta(
    String text, {
    String? modelId,
    String? modelName,
    String? conversationId,
  }) =>
      OtyaSupportStreamEvent._(
        type: 'delta',
        delta: text,
        modelId: modelId,
        modelName: modelName,
        conversationId: conversationId,
      );

  factory OtyaSupportStreamEvent.done({
    String? modelId,
    String? modelName,
    String? conversationId,
  }) =>
      OtyaSupportStreamEvent._(
        type: 'done',
        modelId: modelId,
        modelName: modelName,
        conversationId: conversationId,
        complete: true,
      );
}

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
        name: '${json['name'] ?? json['id'] ?? 'Next'}',
        provider: '${json['provider'] ?? ''}',
        tier: '${json['tier'] ?? ''}',
        description: '${json['description'] ?? ''}',
        guest: json['guest'] == true,
      );
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
  static const _connectTimeout = Duration(seconds: 12);
  static const _maxHistoryEntries = 20;
  static const _maxHistoryChars = 3500;

  String? _conversationId;
  String? _cachedGuestId;

  http.Client get _client => AppHttpClient.instance.client;
  Uri get _uri => Uri.parse('${Environment.workerUrl}/api/ai/chat');

  String _newGuestId() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }

  Future<String> _guestId() async {
    final cached = _cachedGuestId;
    if (cached != null && cached.length >= 16) return cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_guestKey);
      if (existing != null && existing.length >= 16) {
        _cachedGuestId = existing;
        return existing;
      }
      final value = _newGuestId();
      _cachedGuestId = value;
      unawaited(prefs.setString(_guestKey, value));
      return value;
    } catch (_) {
      final value = _newGuestId();
      _cachedGuestId = value;
      return value;
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getValidToken();
    return FirebasePlatformService.instance.protectedHeaders(
      base: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  List<Map<String, String>> _safeHistory(List<Map<String, String>> history) {
    final filtered = history.where((entry) {
      final role = entry['role'];
      final content = entry['content']?.trim() ?? '';
      return (role == 'user' || role == 'assistant') && content.isNotEmpty;
    }).map((entry) {
      final content = entry['content']!.trim();
      return <String, String>{
        'role': entry['role']!,
        'content': content.length <= _maxHistoryChars
            ? content
            : content.substring(0, _maxHistoryChars),
      };
    }).toList(growable: false);

    if (filtered.length <= _maxHistoryEntries) return filtered;
    return filtered.sublist(filtered.length - _maxHistoryEntries);
  }

  void _rememberConversation(Object? value) {
    final id = value?.toString().trim() ?? '';
    if (id.isNotEmpty) _conversationId = id;
  }

  Future<Map<String, dynamic>> _chatBody(
    String question, {
    List<Map<String, String>> history = const <Map<String, String>>[],
    String? model,
  }) async {
    final safeHistory = _safeHistory(history);
    final startsVisibleConversation = safeHistory.isEmpty;
    return <String, dynamic>{
      'message': question.trim(),
      'guest_id': await _guestId(),
      'surface': 'android-assistant',
      if (safeHistory.isNotEmpty) 'history': safeHistory,
      if (startsVisibleConversation) 'new_chat': true,
      if (!startsVisibleConversation && _conversationId?.isNotEmpty == true)
        'conversation_id': _conversationId,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    };
  }

  Future<List<OtyaAiModel>> models() async {
    final response = await _client
        .get(
          _uri.replace(queryParameters: const {'models': '1'}),
          headers: await _headers(),
        )
        .timeout(_timeout);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_error(data, 'Next models are unavailable right now.'));
    }
    final raw = data['models'];
    if (raw is! List) return const <OtyaAiModel>[];
    final result = raw
        .whereType<Map>()
        .map(
          (value) => OtyaAiModel.fromJson(
            value.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .where((model) => model.id.isNotEmpty)
        .toList(growable: true);
    final defaultId = '${data['default_model'] ?? ''}'.trim();
    if (defaultId.isNotEmpty) {
      final index = result.indexWhere((model) => model.id == defaultId);
      if (index > 0) result.insert(0, result.removeAt(index));
    }
    return List<OtyaAiModel>.unmodifiable(result);
  }

  Stream<OtyaSupportStreamEvent> askStream(
    String question, {
    List<Map<String, String>> history = const <Map<String, String>>[],
    String? model,
  }) async* {
    // Start local/preferences work and auth/App Check header preparation together.
    // Neither depends on the other, so serializing them only delays the first
    // network byte and makes Next feel slower.
    final bodyFuture = _chatBody(question, history: history, model: model);
    final headersFuture = _headers();
    final body = await bodyFuture;
    final headers = await headersFuture;
    headers['Accept'] = 'text/event-stream';

    final request = http.Request('POST', _uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    final response = await _client.send(request).timeout(_connectTimeout);
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.stream.bytesToString().timeout(_timeout);
      Map<String, dynamic> data = const <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          data = decoded.map((key, value) => MapEntry('$key', value));
        }
      } catch (_) {}
      throw StateError(_error(data, 'Next is unavailable right now.'));
    }

    if (!contentType.contains('text/event-stream')) {
      final text = await response.stream.bytesToString().timeout(_timeout);
      Map<String, dynamic> data = const <String, dynamic>{};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          data = decoded.map((key, value) => MapEntry('$key', value));
        }
      } catch (_) {}
      _rememberConversation(data['conversation_id']);
      final answer = '${data['answer'] ?? ''}'.trim();
      if (answer.isEmpty) {
        throw StateError(_error(data, 'Next returned an empty response.'));
      }
      yield OtyaSupportStreamEvent.delta(
        answer,
        modelId: data['model']?.toString(),
        modelName: data['model_name']?.toString(),
        conversationId: data['conversation_id']?.toString(),
      );
      yield OtyaSupportStreamEvent.done(
        modelId: data['model']?.toString(),
        modelName: data['model_name']?.toString(),
        conversationId: data['conversation_id']?.toString(),
      );
      return;
    }

    var sawDone = false;
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(_timeout)) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) continue;
        data = decoded.map((key, value) => MapEntry('$key', value));
      } catch (_) {
        continue;
      }
      final event = OtyaSupportStreamEvent.fromJson(data);
      if (event.type.isEmpty) continue;
      _rememberConversation(event.conversationId);
      if (event.isDone) sawDone = true;
      if (event.isError) {
        throw StateError(
          event.error?.trim().isNotEmpty == true
              ? event.error!
              : 'Next stopped responding. Please try again.',
        );
      }
      yield event;
    }
    if (!sawDone) {
      yield OtyaSupportStreamEvent.done(conversationId: _conversationId);
    }
  }

  Future<OtyaSupportReply> ask(
    String question, {
    List<Map<String, String>> history = const <Map<String, String>>[],
    String? model,
  }) async {
    final bodyFuture = _chatBody(question, history: history, model: model);
    final headersFuture = _headers();
    final body = await bodyFuture;
    final headers = await headersFuture;

    final response = await _client
        .post(_uri, headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_error(data, 'Next is unavailable right now.'));
    }
    _rememberConversation(data['conversation_id']);
    final answer = '${data['answer'] ?? ''}'.trim();
    return OtyaSupportReply(
      answer: answer.isEmpty ? 'I could not answer that right now.' : answer,
      inScope: data['scope'] != 'outside-otya',
      handoffAvailable: data['handoff_available'] == true,
      modelId: data['model']?.toString(),
      modelName: data['model_name']?.toString(),
    );
  }

  Future<OtyaSupportTicket> handoff({
    required String question,
    required String email,
  }) async {
    final bodyFuture = _guestId();
    final headersFuture = _headers();
    final guestId = await bodyFuture;
    final headers = await headersFuture;

    final response = await _client
        .post(
          _uri,
          headers: headers,
          body: jsonEncode({
            'message': question.trim(),
            'contact_email': email.trim(),
            'guest_id': guestId,
            'surface': 'android-assistant',
            'request_handoff': true,
          }),
        )
        .timeout(_timeout);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_error(data, 'Could not contact Otya Support.'));
    }
    return OtyaSupportTicket('${data['ticket'] ?? 'Otya'}');
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
