import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _focus = FocusNode();
  final List<_AiMessage> _messages = [];
  bool _busy = false;
  bool _signedIn = false;
  bool _showAccountNotice = true;
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
            rows
                .whereType<Map>()
                .map((row) => _AiMessage(
                      user: row['role'] == 'user',
                      text: '${row['content'] ?? ''}',
                    ))
                .where((message) => message.text.isNotEmpty),
          );
      });
      _scrollToBottom(jump: true);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(_AiMessage(user: true, text: text));
      _busy = true;
      _error = null;
    });
    _scrollToBottom();

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
          .timeout(const Duration(seconds: 35));
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
      setState(() {
        _error = 'Could not reach OTYA AI. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  Future<void> _newChat() async {
    if (_signedIn) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('otya_ai_conversation_id');
    }
    if (!mounted) return;
    setState(() {
      _conversationId = null;
      _messages.clear();
      _error = null;
    });
    _focus.requestFocus();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF11D7FF), Color(0xFF7544FF), Color(0xFFFF2CAA)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 17, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OTYA AI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('by PeterSmart Link',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    )),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _newChat,
            tooltip: 'New chat',
            icon: const Icon(Icons.edit_square),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_showAccountNotice)
              _AccountNotice(
                signedIn: _signedIn,
                onDismiss: () => setState(() => _showAccountNotice = false),
                onSignIn: () => context.push('/auth'),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(onPrompt: (text) {
                      _controller.text = text;
                      _send();
                    })
                  : GestureDetector(
                      onTap: () => _focus.unfocus(),
                      child: ListView.builder(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                        itemCount: _messages.length + (_busy ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return const _ThinkingRow();
                          }
                          final message = _messages[index];
                          return _MessageRow(message: message);
                        },
                      ),
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: Colors.redAccent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderOf(context).withValues(alpha: .65),
                  ),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderOf(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 5),
                    IconButton(
                      tooltip: 'More',
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.textSecondary),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 15.5,
                          height: 1.3,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Message OTYA AI',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 5, 6, 5),
                      child: IconButton.filled(
                        onPressed: _busy ? null : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: _busy
                              ? scheme.surfaceContainerHighest
                              : AppColors.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(42, 42),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : const Icon(Icons.arrow_upward_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountNotice extends StatelessWidget {
  final bool signedIn;
  final VoidCallback onDismiss;
  final VoidCallback onSignIn;
  const _AccountNotice({
    required this.signedIn,
    required this.onDismiss,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(
            signedIn ? Icons.cloud_done_rounded : Icons.history_toggle_off_rounded,
            size: 17,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              signedIn
                  ? 'This conversation can continue on your OTYA account.'
                  : 'Guest chat is temporary. Sign in to keep conversations.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (!signedIn)
            TextButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final _AiMessage message;
  const _MessageRow({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .82,
          ),
          margin: const EdgeInsets.only(left: 40, bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.accentViolet.withValues(alpha: .24),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: SelectableText(
            message.text,
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontSize: 15.5,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF11D7FF), Color(0xFF7544FF)],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.text,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 15.5,
                    height: 1.52,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: message.text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied'),
                            duration: Duration(milliseconds: 900),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.copy_rounded,
                            size: 16, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF11D7FF), Color(0xFF7544FF)],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 15, color: Colors.white),
          ),
          const SizedBox(width: 11),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Thinking…',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
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
      'What is the current OTYA version?',
      'Help me write a message',
      'How do I fix a video that will not play?',
      'Explain something to me',
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 58),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF11D7FF),
                      Color(0xFF7544FF),
                      Color(0xFFFF2CAA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: .18),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 31),
              ),
              const SizedBox(height: 20),
              Text(
                'How can I help?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimaryOf(context),
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask about OTYA, writing, ideas, explanations, troubleshooting, or everyday questions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              ...prompts.map(
                (prompt) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onPrompt(prompt),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_outward_rounded,
                              size: 17, color: AppColors.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              prompt,
                              style: TextStyle(
                                color: AppColors.textPrimaryOf(context),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
