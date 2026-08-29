import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/otya_support_service.dart';

class OtyaSupportScreen extends StatefulWidget {
  const OtyaSupportScreen({super.key});

  @override
  State<OtyaSupportScreen> createState() => _OtyaSupportScreenState();
}

class _ChatEntry {
  final String text;
  final bool fromUser;
  final bool canHandoff;

  const _ChatEntry({
    required this.text,
    required this.fromUser,
    this.canHandoff = false,
  });
}

class _OtyaSupportScreenState extends State<OtyaSupportScreen> {
  final _controller = TextEditingController();
  final _emailController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _service = OtyaSupportService.instance;

  final List<_ChatEntry> _messages = [];
  List<OtyaAiModel> _models = const [];
  OtyaAiModel? _selectedModel;
  bool _busy = false;
  bool _loadingModels = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await _service.models();
      if (!mounted) return;
      setState(() {
        _models = models;
        _selectedModel = models.isEmpty ? null : models.first;
        _loadingModels = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _ask([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _busy) return;

    final history = _messages
        .map(
          (message) => <String, String>{
            'role': message.fromUser ? 'user' : 'assistant',
            'content': message.text,
          },
        )
        .toList(growable: false);

    HapticFeedback.selectionClick();
    _controller.clear();
    setState(() {
      _busy = true;
      _messages.add(_ChatEntry(text: question, fromUser: true));
    });
    _scrollToBottom();

    try {
      final reply = await _service.ask(
        question,
        history: history,
        model: _selectedModel?.id,
      );
      if (!mounted) return;
      setState(() {
        if (reply.modelId != null) {
          for (final candidate in _models) {
            if (candidate.id == reply.modelId) {
              _selectedModel = candidate;
              break;
            }
          }
        }
        _messages.add(
          _ChatEntry(
            text: reply.answer,
            fromUser: false,
            canHandoff: reply.handoffAvailable,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatEntry(
            text:
                'Ask OTYA is unavailable right now. Your local music, video, files and playback still work normally.',
            fromUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _handoff(String question) async {
    _emailController.clear();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardOf(context),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Talk to PeterSmart Link support',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            const Text(
              'This OTYA question may need a human. Enter your email and the question will be sent to support with a ticket number.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Reply email',
                filled: true,
                fillColor: Theme.of(sheetContext).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Send to support'),
              ),
            ),
          ],
        ),
      ),
    );

    if (sent != true || !mounted) return;
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _appendAssistant('Enter a valid email address before sending to support.');
      return;
    }

    setState(() => _busy = true);
    try {
      final ticket = await _service.handoff(question: question, email: email);
      if (!mounted) return;
      _appendAssistant(
        'PeterSmart Link support has been notified. Ticket ${ticket.id}. A reply can be sent to $email.',
      );
    } catch (_) {
      if (mounted) {
        _appendAssistant(
          'I could not send the support request. Try again when you are online or use the OTYA support page.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _appendAssistant(String text) {
    if (!mounted) return;
    setState(() => _messages.add(_ChatEntry(text: text, fromUser: false)));
    _scrollToBottom();
  }

  void _newChat() {
    HapticFeedback.selectionClick();
    setState(() => _messages.clear());
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _questionForAssistantAt(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (_messages[i].fromUser) return _messages[i].text;
    }
    return '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final modelLabel =
        _selectedModel?.name ?? (_loadingModels ? 'Loading…' : 'OTYA');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 19),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ask OTYA'),
                Text(
                  modelLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface.withValues(alpha: .55),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_models.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Choose model',
              icon: const Icon(Icons.tune_rounded),
              onSelected: (id) {
                for (final model in _models) {
                  if (model.id == id) {
                    setState(() => _selectedModel = model);
                    break;
                  }
                }
              },
              itemBuilder: (_) => _models
                  .map(
                    (model) => PopupMenuItem<String>(
                      value: model.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (model.provider.isNotEmpty)
                              Text(
                                '${model.provider}${model.tier.isEmpty ? '' : ' · ${model.tier}'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (model.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                model.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: _busy ? null : _newChat,
              icon: const Icon(Icons.edit_square),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _Welcome(onPrompt: _ask)
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                      itemCount: _messages.length + (_busy ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const _ThinkingRow();
                        }
                        final message = _messages[index];
                        return _MessageRow(
                          message: message,
                          onCopy: message.fromUser
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(text: message.text),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Answer copied'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                          onHandoff: message.canHandoff
                              ? () => _handoff(_questionForAssistantAt(index))
                              : null,
                        );
                      },
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                10 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.borderOf(context)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message Ask OTYA',
                        filled: true,
                        fillColor: AppColors.cardOf(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _busy ? null : () => _ask(),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
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

class _Welcome extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  const _Welcome({required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final prompts = <(String, String)>[
      ('Ask anything', 'Explain photosynthesis in simple language.'),
      ('Learn', 'Give me a simple plan for learning a new skill.'),
      ('OTYA', 'How do I send a large video with OTYA Transfer?'),
      ('Media', 'Why can a video have picture but no sound?'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.accent,
            size: 25,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'What can I help with?',
          style: TextStyle(
            fontSize: 29,
            height: 1.08,
            letterSpacing: -1,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Ask a general question, get help understanding something, or ask about OTYA playback, files, Transfer, Converter, storage, updates and your account.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: colors.onSurface.withValues(alpha: .62),
          ),
        ),
        const SizedBox(height: 26),
        ...prompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onPrompt(prompt.$2),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderOf(context)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prompt.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prompt.$2,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: colors.onSurface.withValues(alpha: .62),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AI can make mistakes and some current facts may have changed. Local playback never depends on Ask OTYA. Never send passwords, OTPs, recovery codes or secret keys.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: colors.onSurface.withValues(alpha: .48),
          ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  final _ChatEntry message;
  final VoidCallback? onCopy;
  final VoidCallback? onHandoff;

  const _MessageRow({
    required this.message,
    this.onCopy,
    this.onHandoff,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (message.fromUser) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(42, 8, 0, 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.42,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent),
              SizedBox(width: 7),
              Text(
                'OTYA',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SelectableText(
            message.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.58,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              if (onCopy != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy answer',
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded, size: 17),
                ),
              if (onHandoff != null)
                TextButton.icon(
                  onPressed: onHandoff,
                  icon: const Icon(Icons.support_agent_rounded, size: 17),
                  label: const Text('Talk to support'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(2, 4, 20, 20),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent),
            SizedBox(width: 10),
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 9),
            Text(
              'Thinking…',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}
