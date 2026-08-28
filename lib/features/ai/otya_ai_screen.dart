import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/config/environment.dart';
import '../../core/services/otya_ai_service.dart';

class OtyaAiScreen extends StatefulWidget {
  const OtyaAiScreen({super.key});

  @override
  State<OtyaAiScreen> createState() => _OtyaAiScreenState();
}

class _OtyaAiScreenState extends State<OtyaAiScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _service = OtyaAiService.instance;

  final List<OtyaAiMessage> _messages = [];
  List<OtyaAiModel> _models = const [];
  List<OtyaAiConversation> _conversations = const [];
  OtyaAiQuota? _quota;
  String _selectedModel = 'otya-smart';
  String? _conversationId;
  bool _signedIn = false;
  bool _busy = false;
  bool _loading = true;
  bool _forceNew = false;
  bool _showAccountNotice = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final signedIn = await _service.isSignedIn();
      final capabilities = await _service.capabilities();
      final savedModel = await _service.selectedModel();
      final allowedIds = capabilities.models.map((model) => model.id).toSet();
      final selected = signedIn
          ? (savedModel != null && allowedIds.contains(savedModel)
              ? savedModel
              : capabilities.defaultModel)
          : capabilities.guestModel;

      String? conversationId;
      List<OtyaAiConversation> conversations = const [];
      if (signedIn) {
        conversationId = await _service.lastConversationId();
        conversations = await _service.listConversations();
      }

      if (!mounted) return;
      setState(() {
        _signedIn = signedIn;
        _models = capabilities.models;
        _selectedModel = selected;
        _quota = capabilities.quota;
        _conversationId = conversationId;
        _conversations = conversations;
        _loading = false;
      });

      if (signedIn && conversationId != null) {
        await _openConversation(conversationId, persistPointer: false);
      }
    } on OtyaAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'OTYA AI is unavailable right now.';
      });
    }
  }

  Future<void> _refreshCapabilities() async {
    try {
      final capabilities = await _service.capabilities();
      if (!mounted) return;
      final allowedIds = capabilities.models.map((model) => model.id).toSet();
      setState(() {
        _models = capabilities.models;
        _quota = capabilities.quota;
        if (!allowedIds.contains(_selectedModel)) {
          _selectedModel = _signedIn
              ? capabilities.defaultModel
              : capabilities.guestModel;
        }
        _error = null;
      });
    } catch (_) {}
  }

  Future<void> _refreshConversations() async {
    if (!_signedIn) return;
    try {
      final rows = await _service.listConversations();
      if (mounted) setState(() => _conversations = rows);
    } catch (_) {}
  }

  Future<void> _openConversation(
    String id, {
    bool persistPointer = true,
  }) async {
    if (!_signedIn) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final conversation = await _service.getConversation(id);
      if (conversation == null) return;
      if (persistPointer) await _service.setLastConversationId(id);
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _forceNew = false;
        _messages
          ..clear()
          ..addAll(conversation.messages);
      });
      _scrollToBottom(jump: true);
    } on OtyaAiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    final guestHistory = List<OtyaAiMessage>.from(_messages);
    _controller.clear();
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(OtyaAiMessage(role: 'user', content: text));
      _busy = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final reply = await _service.send(
        message: text,
        conversationId: _conversationId,
        model: _signedIn ? _selectedModel : null,
        newChat: _signedIn && _forceNew,
        guestHistory: guestHistory,
      );
      if (_signedIn && reply.conversationId != null) {
        _conversationId = reply.conversationId;
        _forceNew = false;
        await _service.setLastConversationId(reply.conversationId);
      }
      if (!mounted) return;
      setState(() {
        _quota = reply.quota ?? _quota;
        _messages.add(OtyaAiMessage(role: 'assistant', content: reply.answer));
      });
      if (_signedIn) await _refreshConversations();
    } on OtyaAiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
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
    if (_signedIn) await _service.setLastConversationId(null);
    if (!mounted) return;
    setState(() {
      _conversationId = null;
      _forceNew = _signedIn;
      _messages.clear();
      _error = null;
    });
    _focus.requestFocus();
  }

  Future<void> _chooseModel(String model) async {
    if (!_signedIn) return;
    await _service.setSelectedModel(model);
    if (mounted) setState(() => _selectedModel = model);
  }

  Future<void> _openHistoryAndSettings() async {
    await _refreshConversations();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardOf(context),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'OTYA AI',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _newChat();
                        },
                        icon: const Icon(Icons.edit_square, size: 17),
                        label: const Text('New chat'),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(_signedIn ? 'OTYA Account' : 'Sign in to OTYA'),
                  subtitle: Text(
                    _signedIn
                        ? 'Manage account, security and AI preferences'
                        : 'Save chats and unlock model selection',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(_signedIn ? '/profile' : '/auth');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('OTYA Docs'),
                  subtitle: const Text('Privacy, terms, support and account docs'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/webview', extra: {
                      'url': Environment.docsUrl,
                      'title': 'OTYA Docs',
                    });
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Text(
                    _signedIn ? 'Recent chats' : 'Conversation history',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: !_signedIn
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Guest chats are temporary and are not saved to your OTYA account.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : _conversations.isEmpty
                          ? const Center(
                              child: Text(
                                'No saved chats yet.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _conversations.length,
                              itemBuilder: (context, index) {
                                final item = _conversations[index];
                                return ListTile(
                                  leading: const Icon(Icons.chat_bubble_outline_rounded),
                                  title: Text(
                                    item.title.isEmpty ? 'New chat' : item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  selected: item.id == _conversationId,
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _openConversation(item.id);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    OtyaAiModel? selected;
    for (final model in _models) {
      if (model.id == _selectedModel) {
        selected = model;
        break;
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 14,
        title: Row(
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
              child: const Icon(Icons.auto_awesome_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('OTYA AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    _signedIn
                        ? (selected?.name ?? 'General assistant')
                        : 'Guest · ${selected?.name ?? 'OTYA Fast'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_signedIn && _models.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Choose AI model',
              initialValue: _selectedModel,
              onSelected: _chooseModel,
              icon: const Icon(Icons.tune_rounded),
              itemBuilder: (context) => _models
                  .map(
                    (model) => PopupMenuItem<String>(
                      value: model.id,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${model.provider} · ${model.tier}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(onPressed: _newChat, tooltip: 'New chat', icon: const Icon(Icons.edit_square)),
          IconButton(
            onPressed: _openHistoryAndSettings,
            tooltip: 'Chats and settings',
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_showAccountNotice)
              _StatusStrip(
                signedIn: _signedIn,
                quota: _quota,
                onDismiss: () => setState(() => _showAccountNotice = false),
                onSignIn: () => context.push('/auth'),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _EmptyState(
                          signedIn: _signedIn,
                          onPrompt: (text) {
                            _controller.text = text;
                            _send();
                          },
                        )
                      : GestureDetector(
                          onTap: () => _focus.unfocus(),
                          child: ListView.builder(
                            controller: _scroll,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                            itemCount: _messages.length + (_busy ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) return const _ThinkingRow();
                              return _MessageRow(message: _messages[index]);
                            },
                          ),
                        ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                    TextButton(onPressed: _refreshCapabilities, child: const Text('Retry')),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: AppColors.borderOf(context).withValues(alpha: .65)),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 12),
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
                          backgroundColor: _busy ? scheme.surfaceContainerHighest : AppColors.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(42, 42),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
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

class _StatusStrip extends StatelessWidget {
  final bool signedIn;
  final OtyaAiQuota? quota;
  final VoidCallback onDismiss;
  final VoidCallback onSignIn;

  const _StatusStrip({
    required this.signedIn,
    required this.quota,
    required this.onDismiss,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final quotaText = quota == null ? '' : ' · ${quota!.remaining}/${quota!.limit} AI credits left';
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
              signedIn ? 'Saved to your OTYA account$quotaText.' : 'Guest chat is temporary$quotaText.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
          if (!signedIn) TextButton(onPressed: onSignIn, child: const Text('Sign in')),
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
  final OtyaAiMessage message;
  const _MessageRow({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
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
            message.content,
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
              gradient: const LinearGradient(colors: [Color(0xFF11D7FF), Color(0xFF7544FF)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.content,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 15.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 5),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: message.content)),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy'),
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
    return const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('OTYA AI is thinking…', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool signedIn;
  final ValueChanged<String> onPrompt;

  const _EmptyState({required this.signedIn, required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'Help me organise my music library',
      'Explain something I am learning',
      'Help me write a professional message',
      'How can I fix a video that will not play?',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 30),
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF11D7FF), Color(0xFF7544FF), Color(0xFFFF2CAA)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'What can I help with?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          signedIn
              ? 'Ask general questions or get OTYA help. Your signed-in chats can continue across OTYA clients.'
              : 'Ask anything. Guest chats are temporary; sign in to save chats and choose more models.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 26),
        ...prompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onPrompt(prompt),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
              child: Text(prompt),
            ),
          ),
        ),
      ],
    );
  }
}
