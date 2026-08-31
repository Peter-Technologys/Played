import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/otya_support_service.dart';
import '../../shared/widgets/otya_logo.dart';

class OtyaSupportScreen extends StatefulWidget {
  const OtyaSupportScreen({super.key});

  @override
  State<OtyaSupportScreen> createState() => _OtyaSupportScreenState();
}

class _ChatEntry {
  const _ChatEntry({
    required this.text,
    required this.fromUser,
    this.canHandoff = false,
  });

  final String text;
  final bool fromUser;
  final bool canHandoff;
}

class _OtyaSupportScreenState extends State<OtyaSupportScreen> {
  final _controller = TextEditingController();
  final _emailController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _service = OtyaSupportService.instance;

  final List<_ChatEntry> _messages = <_ChatEntry>[];
  List<OtyaAiModel> _models = const <OtyaAiModel>[];
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
        final modelId = reply.modelId;
        if (modelId != null) {
          for (final candidate in _models) {
            if (candidate.id == modelId) {
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
                'I cannot reach Next right now. You can keep using your music, videos, files, Transfer and other local Otya features normally.',
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
            const Row(
              children: [
                OtyaAiMark(size: 34),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ask Otya Support',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'If this needs a person, Next can create an Otya Support ticket for you.',
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
              height: 50,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Send to support'),
              ),
            ),
          ],
        ),
      ),
    );

    if (sent != true || !mounted) return;
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _appendAssistant('Please enter a valid email address before sending.');
      return;
    }

    setState(() => _busy = true);
    try {
      final ticket = await _service.handoff(question: question, email: email);
      if (!mounted) return;
      _appendAssistant(
        'Done. Otya Support received your request as ticket ${ticket.id}. A reply can be sent to $email.',
      );
    } catch (_) {
      if (mounted) {
        _appendAssistant(
          'I could not send the support request right now. Please try again when you are online.',
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
    if (_busy) return;
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
        duration: const Duration(milliseconds: 240),
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
    final modelLabel = _selectedModel?.name ??
        (_loadingModels ? 'Connecting…' : 'Ready');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              const OtyaThinkingMark(size: 30)
            else
              const OtyaAiMark(size: 30),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Next'),
                Text(
                  _busy ? 'Thinking…' : modelLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface.withValues(alpha: .56),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_models.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Choose Next model',
              icon: const Icon(Icons.tune_rounded),
              onSelected: _busy
                  ? null
                  : (id) {
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (model.description.isNotEmpty)
                              Text(
                                model.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
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
                                      content: Text('Copied'),
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
            _Composer(
              controller: _controller,
              focusNode: _focusNode,
              busy: _busy,
              onSend: _ask,
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const prompts = <(IconData, String, String)>[
      (Icons.lightbulb_outline_rounded, 'Ask anything', 'Explain something to me in simple language.'),
      (Icons.school_outlined, 'Learn', 'Help me make a simple plan to learn a new skill.'),
      (Icons.swap_horiz_rounded, 'Otya Transfer', 'How do I send a large video with Otya Transfer?'),
      (Icons.play_circle_outline_rounded, 'Playback help', 'Why can a video have picture but no sound?'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 36),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: const OtyaAiMark(size: 48),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'How can Next help?',
          style: TextStyle(
            fontSize: 30,
            height: 1.08,
            letterSpacing: -1,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Ask Next a question, learn something, or get help with Otya. You can talk naturally — you do not need special commands.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: colors.onSurface.withValues(alpha: .64),
          ),
        ),
        const SizedBox(height: 24),
        ...prompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onPrompt(prompt.$3),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context).withValues(alpha: .72),
                  border: Border.all(color: AppColors.borderOf(context)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(prompt.$1, size: 22, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prompt.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(
                            prompt.$3,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.onSurface.withValues(alpha: .62),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Message Next',
                filled: true,
                fillColor: AppColors.cardOf(context),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 48,
            child: IconButton.filled(
              tooltip: busy ? 'Next is thinking' : 'Send message',
              onPressed: busy ? null : () => onSend(),
              icon: busy
                  ? const OtyaThinkingMark(size: 24)
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, this.onCopy, this.onHandoff});

  final _ChatEntry message;
  final VoidCallback? onCopy;
  final VoidCallback? onHandoff;

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
            child: Text(message.text),
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
              OtyaAiMark(size: 22),
              SizedBox(width: 8),
              Text('Next', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 9),
          SelectableText(
            message.text,
            style: TextStyle(fontSize: 14, height: 1.58, color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              if (onCopy != null)
                IconButton(
                  tooltip: 'Copy answer',
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                ),
              if (onHandoff != null)
                TextButton.icon(
                  onPressed: onHandoff,
                  icon: const Icon(Icons.support_agent_rounded, size: 18),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 20, 20),
        child: Semantics(
          liveRegion: true,
          label: 'Next is thinking',
          child: const Row(
            children: [
              OtyaThinkingMark(size: 30),
              SizedBox(width: 11),
              Text(
                'Next is thinking…',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}
