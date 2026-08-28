import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../../core/config/environment.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/http_client.dart';

class _AiMessage {
  final bool user;
  final String text;
  const _AiMessage({required this.user, required this.text});
}

class OtyaAiScreen extends StatefulWidget {
  const OtyaAiScreen({super.key});

  @override
  State<OtyaAiScreen> createState() => _OtyaAiScreenState();
}

class _OtyaAiScreenState extends State<OtyaAiScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_AiMessage> _messages = [];
  bool _busy = false;
  bool _signedIn = false;
  String? _conversationId;
  String? _error;

  http.Client get _client => AppHttpClient.instance.client;
  Uri get _chatUri => Uri.parse('${Environment.workerUrl}/api/ai/chat');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final signedIn = await AuthService.instance.checkIsLoggedIn();
    String? conversationId;
    if (signedIn) {
      final prefs = await SharedPreferences.getInstance();
      conversationId = prefs.getString('otya_ai_conversation_id');
    }
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _conversationId = conversationId;
    });
    if (signedIn && conversationId != null) {
      await _loadConversation(conversationId);
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getValidToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadConversation(String id) async {
    try {
      final token = await AuthService.instance.getValidToken();
      if (token == null) return;
      final uri = _chatUri.replace(queryParameters: {'conversation_id': id});
      final res = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return;
      final conversation = data['conversation'];
      if (conversation is! Map) return;
      final rows = conversation['messages'];
      if (rows is! List || !mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(
            rows.whereType<Map>().map((row) => _AiMessage(
                  user: row['role'] == 'user',
                  text: '${row['content'] ?? ''}',
                )).where((message) => message.text.isNotEmpty),
          );
      });
      _jumpToEnd();
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(_AiMessage(user: true, text: text));
      _busy = true;
      _error = null;
    });
    _jumpToEnd();

    try {
      final headers = await _headers();
      final tokenPresent = headers.containsKey('Authorization');
      final body = <String, dynamic>{
        'message': text,
        if (_conversationId != null) 'conversation_id': _conversationId,
        if (!tokenPresent)
          'history': _messages
              .take(_messages.length - 1)
              .map((message) => {
                    'role': message.user ? 'user' : 'assistant',
                    'content': message.text,
                  })
              .toList(),
      };
      final res = await _client
          .post(_chatUri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          data is Map
              ? (data['error'] ?? 'OTYA AI is unavailable')
              : 'OTYA AI is unavailable',
        );
      }
      final answer = data is Map ? '${data['answer'] ?? ''}' : '';
      final conversationId =
          data is Map ? data['conversation_id'] as String? : null;
      if (conversationId != null && tokenPresent) {
        _conversationId = conversationId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('otya_ai_conversation_id', conversationId);
      }
      if (!mounted) return;
      setState(() {
        _signedIn = tokenPresent;
        _messages.add(_AiMessage(
          user: false,
          text: answer.isEmpty ? 'I could not answer that.' : answer,
        ));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not reach OTYA AI. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
      _jumpToEnd();
    }
  }

  Future<void> _newChat() async {
    if (_signedIn) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('otya_ai_conversation_id');
    }
    setState(() {
      _conversationId = null;
      _messages.clear();
      _error = null;
    });
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'OTYA AI',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _newChat,
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    _signedIn
                        ? Icons.cloud_done_rounded
                        : Icons.history_toggle_off_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _signedIn
                          ? 'Signed in · this chat can be saved to your OTYA account.'
                          : 'Guest mode · this chat is temporary.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (!_signedIn)
                    TextButton(
                      onPressed: () => context.push('/auth'),
                      child: const Text('Sign in'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(onPrompt: (text) {
                      _controller.text = text;
                      _send();
                    })
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _messages.length + (_busy ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'OTYA AI is thinking…',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }
                        final message = _messages[index];
                        return Align(
                          alignment: message.user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 560),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: message.user
                                  ? AppColors.accent.withValues(
                                      alpha: dark ? 0.24 : 0.14,
                                    )
                                  : AppColors.cardOf(context),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: message.user
                                    ? AppColors.accent.withValues(alpha: 0.22)
                                    : AppColors.borderOf(context),
                              ),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: AppColors.textPrimaryOf(context),
                                height: 1.35,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                8,
                14,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message OTYA AI…',
                        filled: true,
                        fillColor: AppColors.cardOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              BorderSide(color: AppColors.borderOf(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              BorderSide(color: AppColors.borderOf(context)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  const _EmptyState({required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'How do I fix a video that will not play?',
      'Explain something to me',
      'Help me write a message',
      'What can OTYA Player do?',
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'How can I help?',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask general questions or get help with OTYA Player.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: prompts
                  .map((prompt) => ActionChip(
                        label: Text(prompt),
                        onPressed: () => onPrompt(prompt),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
