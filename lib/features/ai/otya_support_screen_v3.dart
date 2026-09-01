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
  const _ChatEntry({required this.text, required this.fromUser, this.canHandoff = false});
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

  bool _busy = false;

  Future<void> _ask([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _busy) return;

    final history = _messages
        .where((message) => message.text.trim().isNotEmpty)
        .map((message) => <String, String>{
              'role': message.fromUser ? 'user' : 'assistant',
              'content': message.text,
            })
        .toList(growable: false);

    HapticFeedback.selectionClick();
    _controller.clear();
    setState(() {
      _busy = true;
      _messages.add(_ChatEntry(text: question, fromUser: true));
      _messages.add(const _ChatEntry(text: '', fromUser: false));
    });
    _scrollToBottom();

    var answer = '';
    try {
      await for (final event in _service.askStream(
        question,
        history: history,
      )) {
        if (!mounted) return;
        if (event.isDelta) {
          answer += event.delta!;
          setState(() {
            _messages[_messages.length - 1] = _ChatEntry(text: answer, fromUser: false);
          });
          _scrollToBottom(animated: false);
        }
      }

      if (!mounted) return;
      if (answer.trim().isEmpty) {
        setState(() {
          _messages[_messages.length - 1] = const _ChatEntry(
            text: 'I could not answer that right now. Please try again.',
            fromUser: false,
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = const _ChatEntry(
          text: 'I cannot reach Next right now. You can keep using your music, videos, files, Transfer and other local Otya features normally.',
          fromUser: false,
          canHandoff: true,
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
    final send = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardOf(context),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              OtyaAiMark(size: 34),
              SizedBox(width: 12),
              Text('Ask Otya Support', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Reply email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
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
    if (send != true || !mounted) return;
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _appendAssistant('Please enter a valid email address before sending.');
      return;
    }
    setState(() => _busy = true);
    try {
      final ticket = await _service.handoff(question: question, email: email);
      if (mounted) _appendAssistant('Otya Support received your request as ticket ${ticket.id}.');
    } catch (_) {
      if (mounted) _appendAssistant('I could not send the support request right now. Please try again when you are online.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _appendAssistant(String text) {
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

  String _questionBefore(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (_messages[i].fromUser) return _messages[i].text;
    }
    return '';
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
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
    final status = _busy
        ? (_messages.isNotEmpty && !_messages.last.fromUser && _messages.last.text.isNotEmpty ? 'Responding…' : 'Thinking…')
        : 'Ready';

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (_busy) const OtyaThinkingMark(size: 30) else const OtyaAiMark(size: 30),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Next'),
            Text(status, style: TextStyle(fontSize: 10.5, color: colors.onSurface.withValues(alpha: .6))),
          ]),
        ]),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(tooltip: 'New chat', onPressed: _busy ? null : _newChat, icon: const Icon(Icons.edit_square)),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: _messages.isEmpty
                ? _Welcome(onPrompt: _ask)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageBubble(
                        message: message,
                        streaming: _busy && index == _messages.length - 1 && !message.fromUser,
                        onCopy: message.fromUser || message.text.isEmpty
                            ? null
                            : () => Clipboard.setData(ClipboardData(text: message.text)),
                        onHandoff: message.canHandoff ? () => _handoff(_questionBefore(index)) : null,
                      );
                    },
                  ),
          ),
          _Composer(controller: _controller, focusNode: _focusNode, busy: _busy, onSend: _ask),
        ]),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPrompt});
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 38, 22, 32),
        children: [
          const Align(alignment: Alignment.centerLeft, child: OtyaAiMark(size: 58)),
          const SizedBox(height: 22),
          const Text('How can Next help?', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 10),
          const Text('Ask naturally. Next begins showing its answer as soon as it arrives.', style: TextStyle(color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: 24),
          for (final prompt in const [
            'Explain something to me in simple language.',
            'Help me make a simple plan to learn a new skill.',
            'How do I send a large video with Otya Transfer?',
            'Why can a video have picture but no sound?',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                tileColor: AppColors.cardOf(context),
                title: Text(prompt),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => onPrompt(prompt),
              ),
            ),
        ],
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.streaming, this.onCopy, this.onHandoff});
  final _ChatEntry message;
  final bool streaming;
  final VoidCallback? onCopy;
  final VoidCallback? onHandoff;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: message.fromUser ? colors.primaryContainer : AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: message.fromUser ? null : Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (message.text.isEmpty && streaming)
            const Row(mainAxisSize: MainAxisSize.min, children: [OtyaThinkingMark(size: 24), SizedBox(width: 9), Text('Thinking…')])
          else
            Text(message.text, style: const TextStyle(height: 1.45)),
          if (!message.fromUser && message.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (streaming) ...[
                const SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
                const SizedBox(width: 8),
                const Text('Responding', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ] else if (onCopy != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 17),
                ),
              if (onHandoff != null)
                TextButton.icon(onPressed: onHandoff, icon: const Icon(Icons.support_agent_rounded, size: 17), label: const Text('Support')),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focusNode, required this.busy, required this.onSend});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderOf(context)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !busy,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Message Next',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: busy ? null : () => onSend(),
            icon: busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_upward_rounded),
          ),
        ]),
      );
}
